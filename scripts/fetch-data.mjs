import { mkdir, readFile, writeFile, rename } from 'node:fs/promises';
import { SOURCE, normalizeList, normalizeStorm, normalizeBulletins } from './source.mjs';

const dataDirectory = new URL('../data/',import.meta.url);
const attemptedAt = new Date().toISOString();
await mkdir(new URL('raw/',dataDirectory),{recursive:true});

async function readPrevious(name) {
  try { return JSON.parse(await readFile(new URL(name,dataDirectory),'utf8')); }
  catch (error) { if (error.code==='ENOENT') return null; throw error; }
}
async function save(name,value) {
  const target = new URL(name,dataDirectory);
  const temporary = new URL(`${name}.tmp`,dataDirectory);
  await writeFile(temporary,`${JSON.stringify(value,null,2)}\n`,'utf8');
  await rename(temporary,target);
}
async function request(path,body) {
  const response = await fetch(`${SOURCE.base}${path}`,{
    method:body?'POST':'GET',
    headers:{'Accept':'application/json','User-Agent':'TyphoonObserver/1.0 (15-minute public weather snapshot)',...(body?{'Content-Type':'application/x-www-form-urlencoded'}:{})},
    ...(body?{body:new URLSearchParams(body)}:{}),
    signal:AbortSignal.timeout(20000)
  });
  if (!response.ok) throw new Error(`Source HTTP ${response.status}`);
  const content = await response.text();
  if (content.length>12_000_000) throw new Error('Source response unexpectedly large');
  return JSON.parse(content);
}

const previous = await readPrevious('latest.json');
try {
  const year = Number(new Intl.DateTimeFormat('en',{timeZone:'Asia/Shanghai',year:'numeric'}).format(new Date()));
  const annualLists = await Promise.all([year,year-1].map(async(listYear)=>{
    const raw=await request('/webApi/GetTyphoonListByYear',{year:String(listYear)});
    return {year:listYear,raw,list:normalizeList(raw)};
  }));
  const list=[...new Map(annualLists.slice().reverse().flatMap(({list:items})=>items).map((storm)=>[storm.id,storm])).values()];
  const active = list.filter((storm)=>!storm.ended);
  if (active.length>20) throw new Error('Unexpected active typhoon count');
  const selected = active.length ? active : list.slice().sort((a,b)=>b.id.localeCompare(a.id)).slice(0,1);
  const details = await Promise.all(selected.map(async (storm) => {
    const raw = await request('/webApi/GetTyphoonPathById',{id:storm.id});
    const normalized=normalizeStorm(raw,storm.id);
    if(normalized.ended!==storm.ended) throw new Error('Source lifecycle changed between list and detail');
    return { raw, normalized };
  }));
  let bulletins;
  try { bulletins = normalizeBulletins(await request('/webapi/GetEarlyWarningList?top=5')); }
  catch { bulletins = {status:'unavailable',records:[],scope:'来源预警公报暂无法读取',sourceUrl:SOURCE.url}; }
  const completedAt = new Date().toISOString();
  const snapshot = { schemaVersion:1,source:SOURCE,fetchedAt:completedAt,year,activeCount:active.length,storms:details.map(({normalized})=>normalized),bulletins };
  for(const annual of annualLists) await save(`raw/year-${annual.year}.json`,annual.raw);
  for (const {raw,normalized} of details) await save(`raw/${normalized.id}.json`,raw);
  await save('latest.json',snapshot);
  await save('status.json',{ok:true,lastAttemptAt:attemptedAt,lastSuccessAt:completedAt,message:'来源数据已成功同步',warningsOk:bulletins.status!=='unavailable'});
  console.log(`Synced ${active.length} active typhoons; saved ${details.length} tracks; bulletin status: ${bulletins.status}.`);
} catch (error) {
  await save('status.json',{ok:false,lastAttemptAt:attemptedAt,lastSuccessAt:previous?.fetchedAt??null,message:'本次同步失败，保留上次有效数据'});
  console.error(`Collection failed: ${error.message}`);
  process.exitCode = 1;
}
