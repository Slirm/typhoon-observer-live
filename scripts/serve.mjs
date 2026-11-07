import http from 'node:http';
import { readFile } from 'node:fs/promises';

const root=new URL('../',import.meta.url);
const files=new Map([['/','index.html'],['/index.html','index.html'],['/app.js','app.js'],['/styles.css','styles.css'],['/data/latest.json','data/latest.json'],['/data/status.json','data/status.json']]);
const types={'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json'};
http.createServer(async(request,response)=>{
  const file=files.get(request.url.split('?')[0]);
  if(!file){response.writeHead(404);response.end('Not found');return;}
  try {
    const content=await readFile(new URL(file,root));
    response.setHeader('Content-Type',`${types[file.slice(file.lastIndexOf('.'))]}; charset=utf-8`);
    response.end(content);
  } catch {response.writeHead(404);response.end('Not found');}
}).listen(4173,'127.0.0.1',()=>console.log('http://127.0.0.1:4173'));
