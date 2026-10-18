import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const site=path.join(root,'website');
let checks=0;
const read=name=>readFile(path.join(site,name),'utf8');
for(const filename of ['index.html','privacy.html','brand.html','404.html']){
 const html=await read(filename);
 assert.match(html,/<html lang="en">/);assert.match(html,/<meta name="viewport"/);assert.match(html,/<title>[^<]+<\/title>/);assert.match(html,/<main[ >]/);checks+=4;
 const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(new Set(ids).size,ids.length,`${filename}: duplicate ids`);checks++;
 for(const [,attribute,url]of html.matchAll(/\b(href|src)="([^"]+)"/g)){
  if(/^(https?:|mailto:|data:)/.test(url)||url==='#')continue;
  const [target,fragment]=url.split('#');
  if(!target){assert.ok(ids.includes(fragment),`${filename}: missing #${fragment}`);checks++;continue}
  const resolved=path.resolve(site,target==='/'?'index.html':target.startsWith('/')?target.slice(1):target);assert.ok(resolved.startsWith(site+path.sep));await stat(resolved);checks++;
  if(fragment&&target.endsWith('.html')){const destination=await read(target);assert.ok(destination.includes(`id="${fragment}"`));checks++}
 }
}
const html=await read('index.html');
for(const [,panel]of html.matchAll(/aria-controls="([^"]+)"/g)){assert.ok(html.includes(`id="${panel}"`));checks++}
assert.ok(html.includes('account details anonymized'));assert.ok(html.includes('assets/usage-light.png'));assert.ok(html.includes('prefers-reduced-motion')||(await read('style.css')).includes('prefers-reduced-motion'));checks+=2;
execFileSync(process.execPath,['--check',path.join(site,'app.js')]);checks++;
const release=JSON.parse(await read('release.json'));
if(release.repository!==null){assert.match(release.repository,/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$/)}checks++;
// Check the publishable set, not ignored builds or real user storage.
const files=execFileSync('git',['-C',root,'ls-files','--cached','--others','--exclude-standard','-z'],{encoding:'utf8'}).split('\0').filter(Boolean);
const privateNames=/^(auth|accounts)\.json$|\.(p12|p8|keychain-db|mobileprovision)$/i;
for(const filename of files){
 assert.ok(!privateNames.test(path.basename(filename)),`Private file in public set: ${filename}`);
 if(/\.(swift|md|html|js|mjs|json|yml|sh|py)$/.test(filename)){
  const text=await readFile(path.join(root,filename),'utf8');
  assert.ok(!/\/Users\/nikhil\//.test(text),`Personal path in ${filename}`);
  assert.ok(!/[A-Z0-9._%+-]+@(gmail|outlook|hotmail)\.com/i.test(text),`Personal email in ${filename}`);
 }
 checks++;
}
console.log(`Passed ${checks} structural, link, release, and publishable-file checks (${files.length} public files).`);
