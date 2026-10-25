import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
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
assert.ok(html.includes('Interactive preview · Sample data.'));assert.ok(html.includes('data-app-preview'));assert.ok(!html.includes('assets/showcase-'));assert.ok(html.includes('prefers-reduced-motion')||(await read('style.css')).includes('prefers-reduced-motion'));checks+=4;
for (const name of ['app.js','theme.js','app-preview.js']) { execFileSync(process.execPath,['--check',path.join(site,name)]);checks++; }
execFileSync(process.execPath,['--check',path.join(site,'analytics.js')]);
execFileSync(process.execPath,[path.join(root,'scripts/version.mjs'),'--check'],{stdio:'inherit'});
execFileSync(process.execPath,[path.join(root,'scripts/check-analytics.mjs')],{stdio:'inherit'});
checks+=3;
execFileSync(process.execPath,[path.join(root,'scripts/check-installer.mjs')],{stdio:'inherit'});checks++;
assert.ok(html.includes('curl -fsSL https://usage-desk.nikhilkr.in/install.sh | sh'));checks++;
const install=await read('install.sh');assert.match(install,/source_commit=[a-f0-9]{40}/);assert.match(install,/source_version=\d+\.\d+\.\d+/);checks+=2;
// Keep the production domain, crawler discovery, and share cards consistent.
const origin='https://usage-desk.nikhilkr.in';
const pages=new Map([['index.html','/'],['privacy.html','/privacy.html'],['brand.html','/brand.html']]);
const sitemap=await read('sitemap.xml');
const sitemapURLs=[...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m=>m[1]);
assert.deepEqual(sitemapURLs,[...pages.values()].map(route=>origin+route));checks++;
const robots=await read('robots.txt');
assert.match(robots,/User-agent: \*\s+Allow: \//);
assert.ok(robots.includes(`Sitemap: ${origin}/sitemap.xml`));checks+=2;
for(const [filename,route] of pages){
 const page=await read(filename);
 const meta=(attribute,name)=>page.match(new RegExp(`<meta ${attribute}="${name}" content="([^"]*)"`))?.[1];
 assert.equal([...page.matchAll(/<link rel="canonical" href="([^"]+)"/g)].length,1,`${filename}: one canonical required`);
 assert.ok(page.includes(`<link rel="canonical" href="${origin+route}">`));
 assert.equal(meta('property','og:url'),origin+route);
 assert.equal(meta('property','og:site_name'),'Usage Desk');
 assert.ok(meta('name','description')?.length>40);
 assert.match(meta('name','robots'),/\bindex\b/);
 assert.ok(!/noindex|nosnippet|nofollow/.test(meta('name','robots')));
 assert.equal(meta('name','twitter:card'),'summary_large_image');
 assert.equal(meta('name','twitter:title'),meta('property','og:title'));
 assert.equal(meta('name','twitter:description'),meta('property','og:description'));
 for(const platform of ['og','twitter']){
  const image=meta(platform==='og'?'property':'name',`${platform}:image`);
  assert.ok(image?.startsWith(origin+'/assets/'),`${filename}: absolute share image on production domain`);
  await stat(path.join(site,new URL(image).pathname));
 }
 assert.equal([...page.matchAll(/<h1(?:\s[^>]*)?>/g)].length,1,`${filename}: one page heading`);
 checks+=12;
}
const structured=[...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)];
assert.equal(structured.length,1);
const graph=JSON.parse(structured[0][1]);
assert.equal(graph['@context'],'https://schema.org');
const entities=graph['@graph'];
const entityIDs=entities.map(entity=>entity['@id']);
assert.equal(new Set(entityIDs).size,entityIDs.length,'Structured data IDs must be unique');
assert.equal(entities.find(entity=>entity['@type']==='WebPage').mainEntity['@id'],origin+'/#app');
assert.equal(entities.find(entity=>entity['@type']==='SoftwareSourceCode').codeRepository,'https://github.com/NiKHiLkr23/usage-desk');checks+=3;
const app=graph['@graph'].find(node=>node['@type']==='SoftwareApplication');
assert.equal(app.name,'Usage Desk');assert.equal(app.url,origin+'/');
assert.equal(app.offers.price,0);assert.match(app.operatingSystem,/macOS 14/);
assert.match(app.description,/source code only/);
assert.equal(app.aggregateRating,undefined);assert.equal(app.review,undefined);
assert.equal(app.downloadUrl,undefined,'Source-only app must not advertise an installer');
assert.ok((await readFile(path.join(root,'README.md'),'utf8')).includes('## Build and run'));
assert.ok(app.installUrl.endsWith('#build-and-run'));checks+=11;
const config=JSON.parse(await read('vercel.json'));
const csp=config.headers.flatMap(rule=>rule.headers).find(header=>header.key==='Content-Security-Policy').value;
const digest=createHash('sha256').update(structured[0][1]).digest('base64');
assert.ok(csp.includes(`'sha256-${digest}'`),'Inline structured data needs an exact CSP hash');
assert.ok(!csp.includes("'unsafe-inline'"),'Keep production CSP strict');
const preview=await readFile(path.join(root,'scripts/preview.mjs'),'utf8');
assert.ok(preview.includes("path.join(root,'vercel.json')"),'Preview must read the production headers');
assert.ok(!preview.includes("'unsafe-inline'"),'Preview must not weaken the production CSP');checks+=4;
const domainRedirect=config.redirects.find(rule=>rule.has?.some(condition=>condition.type==='host'));
assert.equal(domainRedirect.source,'/:path*');assert.equal(domainRedirect.destination,origin+'/:path*');
assert.equal(domainRedirect.permanent,true);
const hostPattern=new RegExp(`^(?:${domainRedirect.has[0].value})$`);
assert.ok(hostPattern.test('usage-desk.vercel.app'));
assert.ok(!hostPattern.test(new URL(origin).hostname));
assert.ok(!hostPattern.test('usage-desk-git-feature.vercel.app'));
assert.ok(!hostPattern.test('usage-deskXvercelXapp'));
assert.ok(config.redirects.some(rule=>rule.source==='/index.html'&&rule.destination==='/'&&rule.permanent));checks+=8;
assert.match(await read('404.html'),/<meta name="robots" content="noindex">/);checks++;

const release=JSON.parse(await read('release.json'));
if(release.repository!==null){assert.match(release.repository,/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/?$/)}checks++;
assert.equal(release.version, install.match(/source_version=(\d+\.\d+\.\d+)/)?.[1]);
assert.equal(release.sourceCommit, install.match(/source_commit=([a-f0-9]{40})/)?.[1]);
assert.equal(release.tag, `v${release.version}`);
assert.equal(execFileSync('git',['-C',root,'show',`${release.sourceCommit}:VERSION`],{encoding:'utf8'}).trim(),release.version,'Installer pin must identify a real committed app version');
checks+=4;

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
console.log(`Passed ${checks} structural, SEO, link, release, and publishable-file checks (${files.length} public files).`);
