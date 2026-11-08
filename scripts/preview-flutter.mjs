import http from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,relative,isAbsolute,extname} from 'node:path';

const root=fileURLToPath(new URL('../app/build/web/',import.meta.url));
const port=Number(process.argv[2]??4190);
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.wasm':'application/wasm','.svg':'image/svg+xml','.png':'image/png','.otf':'font/otf','.ttf':'font/ttf','.woff2':'font/woff2','.txt':'text/plain; charset=utf-8'};
await stat(resolve(root,'index.html'));
http.createServer(async(request,response)=>{
  if(!['GET','HEAD'].includes(request.method)){response.writeHead(405);response.end();return;}
  try{
    const pathname=decodeURIComponent(new URL(request.url,'http://localhost').pathname);
    const path=resolve(root,`.${pathname==='/'?'/index.html':pathname}`);
    const rel=relative(root,path);
    if(rel.startsWith('..')||isAbsolute(rel)){response.writeHead(403);response.end('Forbidden');return;}
    const body=await readFile(path);
    response.writeHead(200,{'Content-Type':types[extname(path)]??'application/octet-stream','Content-Length':body.length,'Cache-Control':'no-cache','X-Content-Type-Options':'nosniff'});
    response.end(request.method==='HEAD'?undefined:body);
  }catch{response.writeHead(404);response.end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`Flutter Web review: http://127.0.0.1:${port}/`));
