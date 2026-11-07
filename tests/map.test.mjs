import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

async function setup({offline=false}={}) {
  const calls={lines:[],circles:[],fits:[],views:[],geography:[]};
  const nodes=new Map();
  const element=()=>({style:{},children:[],hidden:false,textContent:'',events:{},setAttribute(){},append(...items){this.children.push(...items);},addEventListener(name,fn){this.events[name]=fn;}});
  const document={getElementById(id){if(!nodes.has(id))nodes.set(id,element());return nodes.get(id);},createElement:element};
  const layer=()=>({addTo(){return this;},clearLayers(){return this;},bindTooltip(){return this;},on(name,fn){this[name]=fn;return this;}});
  const map={...layer(),createPane(){return{style:{}};},setView(...args){calls.views.push(args);return this;},fitBounds(...args){calls.fits.push(args);return this;},invalidateSize(){},getZoom(){return 4;},getBounds(){return{getEast:()=>160,getWest:()=>90};},addLayer(){},removeLayer(){},hasLayer(){return false;},attributionControl:{setPrefix(){}}};
  const L={map:(id,options)=>{calls.options=options;return map;},layerGroup:layer,canvas:()=>({}),latLngBounds:(points)=>points,
    control:{zoom:()=>layer(),scale:()=>layer()},divIcon:(value)=>value,marker:()=>layer(),
    polyline(points,options){calls.lines.push({points,options});return layer();},
    circleMarker(point,options){const result={...layer(),point,options};calls.circles.push(result);return result;},
    geoJSON(data){calls.geography.push(data);return layer();}};
  let selected;
  const context=vm.createContext({document,L,console,fetch:async()=>{if(offline)throw new Error('offline');return{ok:true,json:async()=>({type:'FeatureCollection',features:[]})};}});
  vm.runInContext(await readFile(new URL('../map.js',import.meta.url),'utf8'),context);
  const view=context.createTrackMap((index)=>{selected=index;});
  await new Promise(setImmediate);
  return{view,calls,nodes,getSelected:()=>selected,recover(){offline=false;}};
}

const storm={id:'202631',name:'烟花',ended:false,observations:[{latitude:20,longitude:125,windPower:8},{latitude:23,longitude:128,windPower:10}],forecast:[{latitude:26,longitude:130,windPower:10}]};

test('real map uses latitude/longitude, selectable nodes and preserves the view on node changes',async()=>{
  const {view,calls,getSelected}=await setup();
  view.render(storm,true,1);
  assert.ok(calls.lines.some(({points})=>JSON.stringify(points)==='[[20,125],[23,128]]'));
  assert.ok(calls.lines.some(({points})=>JSON.stringify(points)==='[[23,128],[26,130]]'));
  const fitCount=calls.fits.length;
  view.render(storm,true,0);
  assert.equal(calls.fits.length,fitCount,'selecting a point must not reset the map');
  calls.circles.find((circle)=>circle.point[0]===20 && circle.click).click();
  assert.equal(getSelected(),0);
  view.focusCenter();
  assert.equal(JSON.stringify(calls.views.at(-1)[0]),'[23,128]');
  view.showWorld();
  assert.ok(calls.fits.at(-1)[0][0][1]<-170 && calls.fits.at(-1)[0][1][1]>170);
});

test('ended storms do not display a forecast on the world map',async()=>{
  const {view,calls}=await setup();
  view.render({...storm,ended:true},true,1);
  assert.equal(calls.lines.some(({points})=>points.some(([lat,lon])=>lat===26 && lon===130)),false);
});

test('minimum zoom allows a whole world to fit a narrow phone map',async()=>{
  const {calls}=await setup();
  const longitudeSpan=311/(256*2**calls.options.minZoom)*360;
  assert.ok(longitudeSpan>=356,'the world view must fit its 356-degree bounds in a 311px map');
});

test('map data failure is explicit and can be retried without blocking the storm track',async()=>{
  const {view,calls,nodes,recover}=await setup({offline:true});
  assert.equal(nodes.get('map-retry').hidden,false);
  assert.match(nodes.get('map-status').textContent,/失败/);
  view.render(storm,false,1);
  assert.ok(calls.circles.some(({point})=>point[0]===23 && point[1]===128));
  recover();
  await nodes.get('map-retry').events.click();
  assert.equal(nodes.get('map-retry').hidden,true);
  assert.equal(calls.geography.length,1);
});
