import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, copyFile, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

async function sandbox(mock,run) {
  const directory=await mkdtemp(join(tmpdir(),'typhoon-collector-test-'));
  try {
    await mkdir(join(directory,'scripts'));
    await mkdir(join(directory,'data'));
    await copyFile(new URL('../scripts/source.mjs',import.meta.url),join(directory,'scripts/source.mjs'));
    await copyFile(new URL('../scripts/fetch-data.mjs',import.meta.url),join(directory,'scripts/fetch-data.mjs'));
    const mockPath=join(directory,'mock.mjs');
    await writeFile(mockPath,mock);
    const previous={schemaVersion:1,fetchedAt:'2026-11-01T00:00:00.000Z',storms:[{id:'retained'}]};
    await writeFile(join(directory,'data/latest.json'),JSON.stringify(previous));
    const result=spawnSync(process.execPath,['--import',pathToFileURL(mockPath).href,join(directory,'scripts/fetch-data.mjs')],{encoding:'utf8',timeout:10000});
    assert.ifError(result.error);
    await run({directory,result,previous});
  } finally {
    assert.ok(resolve(directory).startsWith(`${resolve(tmpdir())}${sep}typhoon-collector-test-`));
    await rm(directory,{recursive:true,force:true});
  }
}

test('upstream failure preserves last valid snapshot and records failed attempt',async()=>{
  await sandbox(`globalThis.fetch=async()=>new Response('unavailable',{status:503});`,async({directory,result,previous})=>{
    assert.equal(result.status,1);
    assert.match(result.stderr,/Collection failed: Source HTTP 503/);
    assert.deepEqual(JSON.parse(await readFile(join(directory,'data/latest.json'),'utf8')),previous);
    const status=JSON.parse(await readFile(join(directory,'data/status.json'),'utf8'));
    assert.equal(status.ok,false);
    assert.equal(status.lastSuccessAt,previous.fetchedAt);
    assert.ok(Date.parse(status.lastAttemptAt));
  });
});
test('malformed upstream response cannot erase saved data as an empty list',async()=>{
  await sandbox(`globalThis.fetch=async()=>new Response('<html>maintenance</html>');`,async({directory,result,previous})=>{
    assert.equal(result.status,1);
    assert.match(result.stderr,/Collection failed:/);
    assert.deepEqual(JSON.parse(await readFile(join(directory,'data/latest.json'),'utf8')),previous);
    assert.equal(JSON.parse(await readFile(join(directory,'data/status.json'),'utf8')).ok,false);
  });
});
test('valid empty source list is saved without claiming absence of local warnings',async()=>{
  await sandbox(`globalThis.fetch=async()=>Response.json([]);`,async({directory,result})=>{
    assert.equal(result.status,0,result.stderr);
    const data=JSON.parse(await readFile(join(directory,'data/latest.json'),'utf8'));
    assert.equal(data.activeCount,0);
    assert.deepEqual(data.storms,[]);
    assert.equal(data.bulletins.status,'unknown');
    assert.equal(JSON.parse(await readFile(join(directory,'data/status.json'),'utf8')).ok,true);
  });
});
test('Beijing New Year retains an active typhoon numbered in the previous year',async()=>{
  const mock=`
    const RealDate=Date;
    globalThis.Date=class extends RealDate { constructor(...args){super(...(args.length?args:['2025-12-31T16:30:00Z']));} static now(){return RealDate.parse('2025-12-31T16:30:00Z');} };
    const storm={TyphoonId:'202599',Year:2025,CnName:'测试台风',EnName:'Test',IsStop:false};
    globalThis.fetch=async(url,options)=>{
      if(url.includes('GetTyphoonListByYear')) return Response.json(options.body.get('year')==='2025'?[storm]:[]);
      if(url.includes('GetTyphoonPathById')) return Response.json({...storm,TyphoonPath:[{Time:'12-31 20:00',Lon:120,Lat:20,CenterWindPower:8,CenterWindSpeed:20,CenterPressure:990,MoveSpeed:10,MoveDirection:'西',ForecastData:[]}]});
      return Response.json([]);
    };`;
  await sandbox(mock,async({directory,result})=>{
    assert.equal(result.status,0,result.stderr);
    const data=JSON.parse(await readFile(join(directory,'data/latest.json'),'utf8'));
    assert.equal(data.year,2026);
    assert.equal(data.activeCount,1);
    assert.equal(data.storms[0].id,'202599');
    assert.equal(data.storms[0].ended,false);
    assert.equal(JSON.parse(await readFile(join(directory,'data/raw/year-2025.json'),'utf8'))[0].TyphoonId,'202599');
  });
});
