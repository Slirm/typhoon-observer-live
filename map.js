"use strict";

function createTrackMap(onSelect) {
  const map=L.map('track-map',{zoomControl:false,minZoom:0,maxZoom:7,zoomSnap:.25,scrollWheelZoom:false,maxBounds:[[-80,-180],[80,180]],maxBoundsViscosity:1,zoomAnimation:false,fadeAnimation:false,markerZoomAnimation:false}).setView([24,126],4);
  map.attributionControl.setPrefix('<a href="https://leafletjs.com" target="_blank" rel="noopener noreferrer">Leaflet</a>');
  L.control.zoom({position:'topright',zoomInTitle:'放大地图',zoomOutTitle:'缩小地图'}).addTo(map);
  L.control.scale({position:'bottomleft',imperial:false,maxWidth:100}).addTo(map);
  // Leaflet panes keep the land below the paths and labels.
  map.createPane('land').style.zIndex=200;
  map.createPane('grid').style.zIndex=250;
  const landRenderer=L.canvas({pane:'land',padding:.5});
  const track=L.layerGroup().addTo(map);
  const nearLabels=L.layerGroup();
  const detailLabels=L.layerGroup();
  const worldLabels=L.layerGroup();
  let current=null;
  let visiblePoints=[];

  for(let lon=-180;lon<=180;lon+=10) L.polyline([[-75,lon],[80,lon]],{pane:'grid',color:'#86aeb9',weight:.5,opacity:.35,interactive:false}).addTo(map);
  for(let lat=-60;lat<=70;lat+=10) L.polyline([[lat,-180],[lat,180]],{pane:'grid',color:'#86aeb9',weight:.5,opacity:.35,interactive:false}).addTo(map);
  function label(group,lat,lon,text,kind) {
    const span=document.createElement('span');span.textContent=text;
    L.marker([lat,lon],{icon:L.divIcon({html:span,className:`map-place ${kind}`,iconSize:[0,0]}),interactive:false,keyboard:false}).addTo(kind==='city'||kind==='island'?detailLabels:group);
  }
  for(const [lat,lon,name,kind] of [[34,108,'中国','country'],[23.7,121,'台湾岛','island'],[19.2,109.7,'海南岛','island'],[37,138,'日本','country'],[16,122,'菲律宾','country'],[20,104,'越南','country'],[36.5,128,'朝鲜半岛','island'],[17,115,'南 海','sea'],[30,130,'东 海','sea'],[21,145,'西 北 太 平 洋','sea'],[31.2,121.5,'上海','city'],[24.5,118.1,'厦门','city'],[22.3,114.2,'香港','city'],[20.0,110.3,'海口','city'],[35.7,139.7,'东京','city'],[14.6,121,'马尼拉','city']]) label(nearLabels,lat,lon,name,kind);
  for(const [lat,lon,name] of [[43,90,'亚 洲'],[48,15,'欧 洲'],[5,20,'非 洲'],[43,-105,'北 美 洲'],[-16,-60,'南 美 洲'],[-25,135,'大 洋 洲'],[12,-145,'太 平 洋'],[5,-35,'大 西 洋'],[-20,75,'印 度 洋']]) label(worldLabels,lat,lon,name,'continent');
  function updateLabels() {
    const bounds=map.getBounds();
    const span=bounds.getEast()-bounds.getWest();
    const near=span<120;
    document.getElementById('track-map').setAttribute('data-world',String(!near));
    const show=near?nearLabels:worldLabels,hide=near?worldLabels:nearLabels;
    if(map.hasLayer(hide))map.removeLayer(hide);
    if(!map.hasLayer(show))map.addLayer(show);
    if(span<55) { if(!map.hasLayer(detailLabels))map.addLayer(detailLabels); }
    else if(map.hasLayer(detailLabels))map.removeLayer(detailLabels);
  }
  map.on('zoomend resize',updateLabels);
  updateLabels();

  async function loadLand() {
    const status=document.getElementById('map-status'),retry=document.getElementById('map-retry');
    status.textContent='正在加载世界海岸线…';retry.hidden=true;
    try {
      const response=await fetch('./assets/maps/ne_50m_land.geojson');
      if(!response.ok)throw new Error('land unavailable');
      const data=await response.json();
      if(data.type!=='FeatureCollection'||!Array.isArray(data.features))throw new Error('invalid land');
      L.geoJSON(data,{pane:'land',renderer:landRenderer,interactive:false,attribution:'底图：<a href="https://www.naturalearthdata.com/" target="_blank" rel="noopener noreferrer">Natural Earth</a>',style:{color:'#91afb2',weight:.8,fillColor:'#f4f6f1',fillOpacity:1}}).addTo(map);
      status.textContent='真实海岸线 · 可拖动、双击或用＋／−缩放';
    } catch {
      status.textContent='海岸线加载失败，路径仍可查看。';retry.hidden=false;
    }
  }
  document.getElementById('map-retry').addEventListener('click',loadLand);
  loadLand();

  function fitTrack() {
    if(!current)return;
    map.invalidateSize();
    map.fitBounds(L.latLngBounds([[18,108],[35,122],...visiblePoints.map((point)=>[point.latitude,point.longitude])]),{padding:[38,46],maxZoom:5,animate:false});
  }
  function render(storm,showForecast,selectedIndex) {
    const changed=current?.id!==storm.id;
    current=storm;
    const observations=storm.observations;
    const forecast=showForecast&&!storm.ended?storm.forecast:[];
    visiblePoints=[...observations,...forecast];
    const coords=(points)=>points.map((point)=>[point.latitude,point.longitude]);
    const latest=observations.at(-1),last=observations.length-1;
    track.clearLayers();
    L.polyline(coords(observations),{color:'#fff',weight:7,opacity:.85,interactive:false}).addTo(track);
    L.polyline(coords(observations),{color:'#23768d',weight:3,interactive:false}).addTo(track);
    if(forecast.length)L.polyline(coords([latest,...forecast]),{color:'#9d6026',weight:2.5,dashArray:'7 7',interactive:false}).addTo(track);
    visiblePoints.forEach((point,index)=>{
      const future=index>last;
      const node=L.circleMarker([point.latitude,point.longitude],{radius:index===last?7:2.5,color:index===last?'#fff':future?'#9d6026':'#23768d',fillColor:index===last?'#9d6026':'#fff',fillOpacity:1,weight:index===last?2:1.5,bubblingMouseEvents:false}).addTo(track);
      const tip=document.createElement('span');
      tip.textContent=`${point.latitude.toFixed(1)}°N, ${point.longitude.toFixed(1)}°E · ${point.windPower??'—'}级${future?' · 预报':''}`;
      node.bindTooltip(tip,{direction:'top'}).on('click',()=>onSelect(index));
    });
    const selected=visiblePoints[selectedIndex];
    if(selected)L.circleMarker([selected.latitude,selected.longitude],{radius:12,color:'#9d6026',weight:2,fillOpacity:0,interactive:false}).addTo(track);
    const title=document.createElement('div'),name=document.createElement('strong'),detail=document.createElement('span');
    name.textContent=`${storm.name} · ${storm.ended?'最后实况':'最新中心'}`;
    detail.textContent=`${latest.windPower??'—'}级 / ${storm.id}`;
    title.append(name,detail);
    L.circleMarker([latest.latitude,latest.longitude],{radius:20,color:'#9d6026',weight:1,opacity:.25,fillColor:'#9d6026',fillOpacity:.08,interactive:false}).addTo(track).bindTooltip(title,{permanent:true,direction:'top',offset:[0,-19],className:'storm-map-label'});
    document.getElementById('track-map').setAttribute('aria-label',`${storm.name}${storm.ended?'历史':''}台风路径地图，方向键移动，＋和−缩放`);
    if(changed)fitTrack();
  }
  return{render,fitTrack,focusCenter(){if(current){const point=current.observations.at(-1);map.setView([point.latitude,point.longitude],Math.max(map.getZoom(),5),{animate:false});}},showWorld(){map.fitBounds([[-58,-178],[78,178]],{padding:[12,12],animate:false});}};
}
