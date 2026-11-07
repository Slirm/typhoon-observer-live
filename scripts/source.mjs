export const SOURCE = { name:'海南气象·南海天气台风路径系统', url:'https://www.scsweather.com/Home/Typhoon', base:'https://www.scsweather.com' };

export function sourceTime(value, year) {
  if (typeof value !== 'string') throw new Error('Missing source timestamp');
  const full = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value.trim());
  const short = /^(\d{2})-(\d{2}) (\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value.trim());
  const parts = full ? full.slice(1) : short ? [year, ...short.slice(1)] : null;
  if (!parts) throw new Error('Unrecognized source timestamp');
  const [y,m,d,h,min,sec=0] = parts.map((part) => Number(part ?? 0));
  const calendar = new Date(Date.UTC(y,m-1,d,h,min,sec));
  if (y<1900 || y>2200 || m<1 || m>12 || d<1 || h>23 || min>59 || sec>59 || calendar.getUTCMonth()!==m-1 || calendar.getUTCDate()!==d) throw new Error('Invalid source date');
  return new Date(Date.UTC(y,m-1,d,h-8,min,sec)).toISOString();
}

function nullableNumber(value, min, max) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number<min || number>max) throw new Error('Invalid numeric source field');
  return number;
}

function identity(item) {
  if (!item || typeof item !== 'object' || !/^\d{6,8}$/.test(String(item.TyphoonId)) || typeof item.IsStop !== 'boolean') throw new Error('Invalid typhoon identity or lifecycle');
  return { id:String(item.TyphoonId), name:typeof item.CnName==='string' && item.CnName.trim() ? item.CnName.trim() : '未命名热带低压', english:typeof item.EnName==='string' ? item.EnName.trim() : '', ended:item.IsStop };
}

export function normalizeList(raw) {
  if (!Array.isArray(raw) || raw.length>500) throw new Error('Source did not return a complete typhoon list');
  const list = raw.map((item) => ({ ...identity(item), year:Number(item.Year ?? String(item.TyphoonId).slice(0,4)) }));
  if (new Set(list.map((item)=>item.id)).size!==list.length) throw new Error('Duplicate typhoon identities');
  return list;
}

function normalizePoint(raw, time) {
  const longitude = nullableNumber(raw.Lon,-180,180);
  const latitude = nullableNumber(raw.Lat,-90,90);
  if (longitude===null || latitude===null) throw new Error('Missing path coordinates');
  return { time, longitude, latitude, windPower:nullableNumber(raw.CenterWindPower,0,25), windSpeed:nullableNumber(raw.CenterWindSpeed,0,150), pressure:nullableNumber(raw.CenterPressure,500,1100), moveDirection:typeof raw.MoveDirection==='string' && raw.MoveDirection.trim() ? raw.MoveDirection.trim() : null, moveSpeed:nullableNumber(raw.MoveSpeed,0,300) };
}

function monthOf(time) {
  const value = String(time);
  return Number((/^\d{4}-/.test(value) ? value.slice(5,7) : value.slice(0,2)));
}

export function normalizeStorm(raw, expectedId) {
  const storm = identity(raw);
  if (expectedId && storm.id!==expectedId) throw new Error('Typhoon detail identity mismatch');
  if (!Array.isArray(raw.TyphoonPath) || raw.TyphoonPath.length===0) throw new Error('Missing typhoon observations');
  let year = Number(raw.Year ?? storm.id.slice(0,4));
  let previousMonth = 0;
  const timedRows = raw.TyphoonPath.map((row) => {
    const month = monthOf(row.Time);
    if (previousMonth-month>6) year++;
    previousMonth = month;
    return { raw:row, point:normalizePoint(row,sourceTime(row.Time,year)), year };
  }).sort((a,b)=>a.point.time.localeCompare(b.point.time));
  const latest = timedRows.at(-1);
  if (new Set(timedRows.map(({point})=>point.time)).size!==timedRows.length) throw new Error('Duplicate observation times');
  const rawForecasts = latest.raw.ForecastData ?? [];
  if (!Array.isArray(rawForecasts)) throw new Error('Invalid forecast payload');
  const chinese = rawForecasts.flat().filter((row)=>row && row.ForecastOffice==='中国').map((row) => {
    const issueYear = latest.year - (monthOf(row.ForecastTime)-monthOf(latest.raw.Time)>6 ? 1 : 0);
    const issuedAt = sourceTime(row.ForecastTime,issueYear);
    const validYear = issueYear + (monthOf(row.ForecastTime)-monthOf(row.Time)>6 ? 1 : 0);
    return { issuedAt, point:normalizePoint(row,sourceTime(row.Time,validYear)) };
  });
  const latestIssue = chinese.map(({issuedAt})=>issuedAt).sort().at(-1) ?? null;
  const forecast = chinese.filter(({issuedAt,point})=>issuedAt===latestIssue && point.time>latest.point.time && point.time>issuedAt).map(({point})=>point).sort((a,b)=>a.time.localeCompare(b.time));
  return { ...storm, observations:timedRows.map(({point})=>point), forecast, forecastAgency:latestIssue?'中国':null, forecastIssuedAt:latestIssue };
}

export function normalizeBulletins(raw) {
  if (!Array.isArray(raw)) throw new Error('Invalid warning bulletin feed');
  const records = raw.slice(0,5).map((record) => {
    if (typeof record.TxtTitle!=='string' || !record.TxtTitle.trim()) throw new Error('Missing bulletin title');
    const sourceTimeText=typeof record.ProductTime==='string'?record.ProductTime.trim():'';
    return { title:record.TxtTitle.trim(), issuedAt:/^\d{4}-/.test(sourceTimeText)?sourceTime(sourceTimeText,0):null, sourceTimeText, relieved:record.IsRelieve===true };
  });
  return { status:records.length?'recent_bulletins':'unknown', records, scope:'海南省来源最近5条公报，不是完整地区有效预警清单', sourceUrl:SOURCE.url };
}
