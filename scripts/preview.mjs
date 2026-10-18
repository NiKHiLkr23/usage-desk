import http from 'node:http';
import { readFile, stat, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=await realpath(path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../website'));
const port=Number(process.env.PORT||4320);
if(!Number.isInteger(port)||port<1||port>65535)throw new Error('PORT must be 1–65535');
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.ico':'image/x-icon','.zip':'application/zip'};
const server=http.createServer(async(request,response)=>{
 try{
  if(!['GET','HEAD'].includes(request.method)){response.writeHead(405,{Allow:'GET, HEAD'});response.end();return}
  const pathname=decodeURIComponent(new URL(request.url,'http://localhost').pathname);
  const relative=pathname.endsWith('/')?pathname+'index.html':pathname;
  if(relative.split('/').some(part=>part.startsWith('.')&&part!=='')){response.writeHead(404);response.end('Not found');return}
  const file=await realpath(path.resolve(root,'.'+relative));
  if(!file.startsWith(root+path.sep)){response.writeHead(403);response.end('Forbidden');return}
  const info=await stat(file);if(!info.isFile())throw new Error('Not a file');
  response.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Content-Length':info.size,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"});
  if(request.method==='HEAD')response.end();else response.end(await readFile(file));
 }catch{response.writeHead(404,{'Content-Type':'text/plain'});response.end('Not found')}
});
server.listen(port,'127.0.0.1',()=>console.log(`Usage Desk preview: http://127.0.0.1:${port}/`));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>server.close(()=>process.exit(0)));
