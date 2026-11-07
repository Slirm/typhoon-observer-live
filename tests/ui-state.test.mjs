import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

test('a failed refresh remains visibly uncertain until a later successful read',async()=>{
  const nodes=new Map();
  function element(){
    const classes=new Set();
    return {children:[],dataset:{},style:{},value:'',textContent:'',disabled:false,hidden:false,
      classList:{toggle(name,on){if(on)classes.add(name);else classes.delete(name);},add(name){classes.add(name);},contains(name){return classes.has(name);}},
      append(...items){this.children.push(...items);},replaceChildren(...items){this.children=items;},setAttribute(){},addEventListener(){}};
  }
  const document={getElementById(id){if(!nodes.has(id))nodes.set(id,element());return nodes.get(id);},createElement:element,createElementNS:element,querySelectorAll(){return[];},addEventListener(){}};
  const now=new Date().toISOString();
  const snapshot={schemaVersion:1,fetchedAt:now,activeCount:0,storms:[],bulletins:{status:'unknown',records:[]}};
  let fail=false;
  const context=vm.createContext({document,console,setInterval(){},fetch:async(url)=>{if(fail)throw new Error('offline');return{ok:true,json:async()=>url.includes('status')?{ok:true,lastSuccessAt:now}:snapshot};}});
  vm.runInContext(await readFile(new URL('../app.js',import.meta.url),'utf8'),context);
  await new Promise(setImmediate);
  assert.equal(nodes.get('data-badge').textContent,'暂无活跃台风');
  fail=true;
  await vm.runInContext('loadSnapshot()',context);
  assert.equal(nodes.get('data-badge').textContent,'读取失败');
  vm.runInContext('renderFreshness()',context);
  assert.ok(nodes.get('data-banner').classList.contains('is-stale'));
  assert.match(nodes.get('data-message').textContent,/读取|异常|过期/);
  fail=false;
  await vm.runInContext('loadSnapshot()',context);
  assert.equal(nodes.get('data-badge').textContent,'暂无活跃台风');
  assert.equal(nodes.get('data-banner').classList.contains('is-stale'),false);
});
