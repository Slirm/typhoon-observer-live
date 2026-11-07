"use strict";

const $ = (id) => document.getElementById(id);
const svgNS = 'http://www.w3.org/2000/svg';
const dateFormat = new Intl.DateTimeFormat('zh-CN',{timeZone:'Asia/Shanghai',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false});
let snapshot = null;
let health = null;
let snapshotReadFailed = false;
let selectedPoint = 0;
let extent = {west:104,east:135,south:12,north:36};

function displayTime(time) { return time ? `${dateFormat.format(new Date(time))}（北京时）` : '未提供'; }
function value(number) { return number===null || number===undefined ? '—' : String(number); }
function currentStorm() { return snapshot?.storms.find((storm)=>storm.id===$('storm-select').value); }
function project([longitude,latitude]) { return [(longitude-extent.west)/(extent.east-extent.west)*940,(extent.north-latitude)/(extent.north-extent.south)*610]; }
function svgElement(tag,attributes={},text='') {
  const element = document.createElementNS(svgNS,tag);
  for (const [key,item] of Object.entries(attributes)) element.setAttribute(key,item);
  if (text) element.textContent = text;
  return element;
}
function pointString(points) { return points.map((point)=>project(point).join(',')).join(' '); }
function coordinates(point) { return [point.longitude,point.latitude]; }

function drawGeography() {
  $('geography').replaceChildren();
  $('map-labels').replaceChildren();
  const shapes = [
    [[104,36],[120,36],[120.8,35.2],[119.6,34.5],[120.5,33.2],[121.8,31.4],[121.4,30.8],[121.9,30.3],[121.3,29.5],[121.7,28.7],[120.8,27.9],[120.2,26.8],[119.3,26],[119.4,25.4],[118.3,24.5],[117.1,23.7],[115.7,22.9],[114.2,22.5],[113.6,22.2],[112.4,21.7],[111,21.5],[110.4,21.1],[110.3,20.4],[109.7,20.3],[109.7,21.4],[108.5,21.5],[107.4,21],[106.6,20],[105.7,19],[106.1,18],[107,16.6],[108.3,15.4],[109.1,13.2],[109,12],[104,12]],
    [[108.6,19.9],[109.4,20.1],[110.6,20],[111,19.4],[110.5,18.7],[109.6,18.2],[108.7,18.5]],
    [[121.5,25.3],[122,24.8],[121.8,23.9],[121.3,22.8],[120.8,21.9],[120.3,22.6],[120.2,23.5],[120.7,24.6]],
    [[120.8,18.6],[121.8,18.4],[122.3,17.5],[122,16.2],[122.7,14.5],[121.7,13.7],[120.7,14.6],[119.8,15.8],[120.2,17.2]],
    [[119.7,12],[120.4,13.4],[121.1,13.1],[121.5,12]]
  ];
  for (const shape of shapes) $('geography').append(svgElement('polygon',{points:pointString(shape),class:'land'}));
  for (const [lon,lat,text,type] of [[111.5,30,'中国大陆',''],[122.2,24.7,'台湾岛',''],[108.8,17.7,'海南岛',''],[123.2,16.1,'菲律宾',''],[113.5,17,'南 海','sea'],[130.7,28.5,'西北太平洋','sea']]) {
    const [x,y] = project([lon,lat]);
    $('map-labels').append(svgElement('text',{x,y,class:`map-label ${type}`},text));
  }
  for (const [lon,lat,name] of [[114.1,22.5,'深圳'],[118.1,24.5,'厦门'],[122.1,30,'舟山'],[110.3,20,'海口']]) {
    const [x,y] = project([lon,lat]);
    $('map-labels').append(svgElement('circle',{cx:x,cy:y,r:4,class:'map-city'}),svgElement('text',{x:x-9,y:y-10,class:'map-label city','text-anchor':'end'},name));
  }
  const step = Math.ceil((extent.east-extent.west)/6/5)*5;
  for (let lon=Math.ceil(extent.west/step)*step;lon<extent.east;lon+=step) {
    const [x] = project([lon,extent.north]);
    $('map-labels').append(svgElement('text',{x,y:22,class:'map-label coordinate','text-anchor':'middle'},`${lon}°E`));
  }
}

function renderTrack() {
  const storm = currentStorm();
  if (!storm) return;
  const last = storm.observations.length-1;
  const showForecast = $('forecast-toggle').checked && !storm.ended;
  if (!showForecast && selectedPoint>last) selectedPoint=last;
  const points = [...storm.observations,...(showForecast?storm.forecast:[])];
  const allCoordinates = points.map(coordinates);
  extent = {west:Math.min(104,...allCoordinates.map(([lon])=>lon))-2,east:Math.max(135,...allCoordinates.map(([lon])=>lon))+3,south:Math.min(12,...allCoordinates.map(([,lat])=>lat))-2,north:Math.max(36,...allCoordinates.map(([,lat])=>lat))+3};
  drawGeography();
  const layer = $('track-layer');
  layer.replaceChildren();
  layer.append(svgElement('polyline',{points:pointString(storm.observations.map(coordinates)),class:'track-observed'}));
  if (showForecast && storm.forecast.length) layer.append(svgElement('polyline',{points:pointString([coordinates(storm.observations[last]),...storm.forecast.map(coordinates)]),class:'track-forecast'}));
  const [cx,cy] = project(coordinates(storm.observations[last]));
  layer.append(svgElement('circle',{cx,cy,r:26,class:'center-halo'}));
  const timelineIndices = [...storm.observations.map((_,index)=>index).slice(-3),...(showForecast?storm.forecast.slice(0,3).map((_,index)=>last+1+index):[])];
  for (const index of timelineIndices) {
    const [x,y] = project(coordinates(points[index]));
    layer.append(svgElement('circle',{cx:x,cy:y,r:index===last?9:5,class:index===last?'center-dot':`track-point${index>last?' future':''}`}));
    if (index===selectedPoint) layer.append(svgElement('circle',{cx:x,cy:y,r:index===last?16:11,class:'point-selected'}));
  }
  const callout = svgElement('g',{class:'map-callout',transform:`translate(${Math.max(8,Math.min(cx+18,754))},${Math.max(25,Math.min(cy+15,535))})`});
  callout.append(svgElement('rect',{width:178,height:61,rx:6}),svgElement('text',{x:12,y:25},`${storm.name} · ${storm.ended?'最后实况':'最新中心'}`),svgElement('text',{x:12,y:45,class:'callout-sub'},`${value(storm.observations[last].windPower)}级 · ${storm.id}`));
  layer.append(callout);
  $('map-svg-title').textContent = `${storm.name}${storm.ended?'历史':''}路径示意，数据来自海南气象·南海天气`;
  const point = points[selectedPoint];
  $('node-type').textContent = selectedPoint>last?'中国机构预报':selectedPoint===last?(storm.ended?'最后实况 · 历史':'最新实况'):'历史实况';
  $('node-time').textContent = displayTime(point.time);
  $('node-detail').textContent = `${point.latitude.toFixed(1)}°N，${point.longitude.toFixed(1)}°E · 最大风力${value(point.windPower)}级`;
  $('timeline').replaceChildren();
  for (const index of timelineIndices) {
    const button=document.createElement('button');
    button.type='button';
    button.setAttribute('aria-pressed',String(index===selectedPoint));
    button.setAttribute('aria-label',`${displayTime(points[index].time)}，${index>last?'预报':'实况'}`);
    button.append(document.createTextNode(dateFormat.format(new Date(points[index].time))));
    const label=document.createElement('span');
    label.textContent=index>last?'预报':index===last?(storm.ended?'最后实况':'最新'):'实况';
    button.append(label);
    button.addEventListener('click',()=>{selectedPoint=index;renderTrack();const target=[...$('timeline').children].find((item)=>item.getAttribute('aria-pressed')==='true');target?.focus({preventScroll:true});});
    $('timeline').append(button);
  }
  $('map-footnote').textContent = storm.ended ? '本图为已停止编号台风的历史路径。下方提供最近3个实况节点；底图简化，不用于导航。' : `实况路径显示已发布记录；预报来自${storm.forecastAgency??'未提供'}，起报时间${displayTime(storm.forecastIssuedAt)}。底图为地理示意。`;
}

function intensity(wind) { return wind===null?'强度未提供':wind>=16?'超强台风':wind>=14?'强台风':wind>=12?'台风':wind>=10?'强热带风暴':wind>=8?'热带风暴':'热带低压'; }
function renderStorm() {
  const storm=currentStorm();
  $('storm-content').hidden=!storm;
  $('empty-state').hidden=Boolean(storm);
  $('track').hidden=!storm;
  if (!storm) return;
  const point=storm.observations.at(-1);
  for (const [id,item] of Object.entries({'storm-name':storm.name,'storm-english':storm.english,'storm-id':storm.id,'storm-intensity':intensity(point.windPower),'storm-place':storm.ended?'已停止编号 · 最后实况位置':'来源最新实况位置','storm-description':storm.ended?'此台风已停止编号，以下为来源保存的历史记录。':`中心向${point.moveDirection??'未提供方向'}移动，具体影响以官方公报为准。`,'storm-wind':value(point.windPower),'storm-wind-speed':value(point.windSpeed),'storm-direction':point.moveDirection??'未提供','storm-move-speed':value(point.moveSpeed),'storm-pressure':value(point.pressure),'storm-lifecycle':storm.ended?'历史台风 · 已停止编号':'活跃台风','observation-time':`实况时次：${displayTime(point.time)}`})) $(id).textContent=item;
  $('storm-position').textContent=`${point.latitude.toFixed(1)}°N / ${point.longitude.toFixed(1)}°E`;
  const rotations={'北':0,'东北':45,'东':90,'东南':135,'南':180,'西南':225,'西':-90,'西北':-45,'北偏东':22.5,'东偏北':67.5,'东偏南':112.5,'南偏东':157.5,'南偏西':202.5,'西偏南':247.5,'西偏北':292.5,'北偏西':337.5};
  $('direction-arrow').style.display=rotations[point.moveDirection]===undefined?'none':'';
  $('direction-arrow').style.transform=`rotate(${rotations[point.moveDirection]??0}deg)`;
  $('forecast-toggle').disabled=storm.ended||!storm.forecast.length;
  $('forecast-toggle').checked=!$('forecast-toggle').disabled;
  $('forecast-note').textContent=storm.ended?'历史记录，仅显示实况':'显示中国机构预报';
  selectedPoint=storm.observations.length-1;
  renderTrack();
}

function renderBulletins() {
  const bulletins=snapshot.bulletins;
  $('warning-card').dataset.level='unknown';
  $('warning-title').textContent='当前预警需官方核实';
  $('warning-time').textContent=`最近读取：${displayTime(snapshot.fetchedAt)}`;
  $('warning-description').textContent=bulletins?.status==='recent_bulletins'?'来源最近公报如下，仅列标题。它们不等同于完整地区有效预警清单，请前往官方原站阅读完整内容和防御指南。':bulletins?.status==='unavailable'?'来源预警公报接口暂无法读取，不能据此判断当地没有预警。请前往官方原站核实。':'来源最近5条公报接口本次未返回记录，不能据此判断海南或其他地区没有预警。请前往官方原站核实。';
  $('bulletin-list').replaceChildren();
  for (const record of bulletins?.records??[]) {
    const item=document.createElement('li');
    const title=document.createElement('strong');title.textContent=record.title;
    const time=document.createElement('p');time.textContent=`${record.issuedAt?displayTime(record.issuedAt):record.sourceTimeText?`${record.sourceTimeText}（来源未提供年份）`:'时间未提供'}${record.relieved?' · 来源标记解除':''}`;
    item.append(title,time);$('bulletin-list').append(item);
  }
}

function renderFreshness() {
  if (!snapshot) return;
  const lastSuccess=health?.lastSuccessAt??snapshot.fetchedAt;
  const age=Date.now()-new Date(lastSuccess).getTime();
  const activeStale=snapshot.storms.some((storm)=>!storm.ended && Date.now()-new Date(storm.observations.at(-1).time).getTime()>12*3600000);
  const stale=snapshotReadFailed||age>45*60000||!health?.ok||activeStale;
  $('data-banner').classList.toggle('is-stale',stale);
  $('data-badge').textContent=stale?'数据需核实':snapshot.activeCount?'真实数据':'暂无活跃台风';
  $('data-message').textContent=stale?'同步异常或数据已过期，请核对官方来源。':snapshot.activeCount?`来源清单中有${snapshot.activeCount}个活跃台风。`:'来源清单当前没有活跃台风；下方展示最近结束台风的历史记录（如有）。';
  $('sync-time').textContent=displayTime(lastSuccess);
  $('sync-time').dateTime=lastSuccess;
  $('last-attempt').textContent=health?.ok?'最近一次采集成功':`最近采集未成功 · ${displayTime(health?.lastAttemptAt)}`;
}

async function loadSnapshot() {
  const button=$('refresh-button');
  if (button.disabled) return;
  button.disabled=true;
  $('refresh-status').textContent='正在读取已采集的数据快照…';
  try {
    const [response,statusResponse]=await Promise.all([fetch('./data/latest.json',{cache:'no-store'}),fetch('./data/status.json',{cache:'no-store'})]);
    if (!response.ok) throw new Error('snapshot unavailable');
    const data=await response.json();
    if (data.schemaVersion!==1 || !Array.isArray(data.storms) || !Number.isFinite(Date.parse(data.fetchedAt)) || data.storms.some((storm)=>!Array.isArray(storm.observations)||!storm.observations.length)) throw new Error('invalid snapshot');
    const previousId=$('storm-select').value;
    snapshot=data;
    snapshotReadFailed=false;
    try {health=statusResponse.ok?await statusResponse.json():null;} catch {health=null;}
    $('storm-select').replaceChildren(...data.storms.map((storm)=>Object.assign(document.createElement('option'),{value:storm.id,textContent:`${storm.name} · ${storm.id}${storm.ended?'（历史）':''}`})));
    if (data.storms.some((storm)=>storm.id===previousId)) $('storm-select').value=previousId;
    $('storm-select').disabled=!data.storms.length;
    renderStorm();renderBulletins();renderFreshness();
    $('refresh-status').textContent='已读取网站快照 · 未直接请求气象来源';
  } catch {
    snapshotReadFailed=true;
    $('data-badge').textContent='读取失败';
    $('data-message').textContent=snapshot?'无法读取新快照，当前保留上次数据，请核对来源与时间。':'数据快照暂不可用。请稍后重试或前往官方原站查询。';
    $('data-banner').classList.add('is-stale');
    $('refresh-status').textContent='读取失败，请重试';
  } finally {button.disabled=false;}
}

$('storm-select').addEventListener('change',renderStorm);
$('forecast-toggle').addEventListener('change',renderTrack);
$('refresh-button').addEventListener('click',loadSnapshot);
const dialog=$('data-dialog');
document.querySelectorAll('[data-open-info]').forEach((button)=>button.addEventListener('click',()=>dialog.showModal()));
$('close-dialog').addEventListener('click',()=>dialog.close());
$('confirm-dialog').addEventListener('click',()=>dialog.close());
document.querySelectorAll('nav a').forEach((link)=>link.addEventListener('click',()=>document.querySelectorAll('nav a').forEach((item)=>item.classList.toggle('active',item===link))));
setInterval(renderFreshness,60000);
setInterval(()=>{if(!document.hidden)loadSnapshot();},15*60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)renderFreshness();});
drawGeography();
loadSnapshot();
