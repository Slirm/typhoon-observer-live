import assert from 'node:assert/strict';
import {readFile,stat} from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const app = new URL('../',import.meta.url);
const html = await readFile(new URL('web/index.html',app),'utf8');

function page() {
  const elements=new Map([...html.matchAll(/id="([^"]+)"/g)].map(([,id])=>[id,{textContent:'',hidden:true,removed:false,remove(){this.removed=true;}}]));
  const events=new Map();
  const eventOptions=new Map();
  const timers=new Map();
  let nextTimer=0;
  const context=vm.createContext({
    window:{addEventListener:(name,callback,options)=>{events.set(name,callback);eventOptions.set(name,options);}},
    document:{getElementById:(id)=>elements.get(id)},
    setTimeout:(callback,ms)=>{timers.set(++nextTimer,{callback,ms});return nextTimer;},
    clearTimeout:(id)=>timers.delete(id),
  });
  const inline=html.match(/<script id="startup">([\s\S]*?)<\/script>/)?.[1]
    ?? html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  vm.runInContext(inline,context);
  return {elements,events,eventOptions,timers,context};
}

async function bootstrap({rejectLoad=false}={}) {
  let source;
  try {source=await readFile(new URL('web/flutter_bootstrap.js',app),'utf8');}
  catch {
    const generated=await readFile(new URL('build/web/flutter_bootstrap.js',app),'utf8');
    source=generated.slice(generated.lastIndexOf('_flutter.loader.load('));
  }
  const state=page();
  let options;
  state.context._flutter={loader:{load:(input)=>{options=input;return rejectLoad?Promise.reject(Error('offline')):Promise.resolve();}}};
  await vm.runInContext(source.replace(/{{flutter_js}}|{{flutter_build_config}}/g,''),state.context);
  return {...state,options};
}

test('startup does not register the obsolete worker that reloads its clients',async()=>{
  const {options}=await bootstrap();
  assert.equal(options?.serviceWorkerSettings,undefined);
});

test('the bundled startup font stays within the 2.5MB payload budget',async()=>{
  const pubspec=await readFile(new URL('pubspec.yaml',app),'utf8');
  const font=pubspec.match(/- asset: (.+\.(?:otf|ttf))/)[1];
  const {size}=await stat(new URL(font,app));
  assert.ok(size<=2_500_000,`startup font is ${size} bytes`);
});

test('slow startup offers recovery, and a late successful frame clears its timer',()=>{
  const {elements,events,timers}=page();
  const slow=[...timers.values()].find(({ms})=>ms===15000);
  assert.ok(slow,'slow-network feedback must start before the bootstrap request');
  slow.callback();
  assert.equal(elements.get('startup-actions').hidden,false);
  events.get('flutter-first-frame')();
  assert.equal(elements.get('loading').removed,true);
  assert.equal(timers.size,0);
});

test('a loader setup rejection exposes recovery',async()=>{
  const {elements}=await bootstrap({rejectLoad:true});
  assert.match(elements.get('startup-status')?.textContent??'',/失败/);
  assert.equal(elements.get('startup-actions')?.hidden,false);
});

test('a dynamic script download failure is caught even when the SDK load promise resolves',async()=>{
  const {elements,events,eventOptions}=await bootstrap();
  assert.equal(eventOptions.get('error'),true,'script download errors need capture phase');
  events.get('error')({target:{tagName:'SCRIPT'}});
  assert.match(elements.get('startup-status').textContent,/失败/);
  assert.equal(elements.get('startup-actions').hidden,false);
});

test('the loader is delivered with the HTML and the font starts downloading early',()=>{
  assert.match(html,/<script id="flutter-boot">{{flutter_bootstrap_js}}<\/script>/);
  assert.match(html,/<link rel="preload" href="assets\/assets\/fonts\/NotoSansSC-Regular.otf" as="fetch"/);
});

test('startup reports real stages and handles engine initialization failure',async()=>{
  const success=await bootstrap();
  let ran=false;
  await success.options.onEntrypointLoaded({initializeEngine:async()=>({runApp:async()=>{ran=true;}})});
  assert.equal(ran,true);
  assert.match(success.elements.get('startup-status').textContent,/页面/);
  const failure=await bootstrap();
  await failure.options.onEntrypointLoaded({initializeEngine:async()=>{throw Error('offline');}});
  assert.match(failure.elements.get('startup-status').textContent,/失败/);
  assert.equal(failure.elements.get('startup-actions').hidden,false);
});
