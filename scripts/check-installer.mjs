import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, chmod, rm, readdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const installer=await readFile(path.join(root,'website/install.sh'),'utf8');
assert.equal(spawnSync('/bin/sh',['-n'],{input:installer}).status,0,'Installer must parse as POSIX sh');
const commit='9366db3b03b1fde7513e1f317e66e454f6d866d2';
const temp=await mkdtemp(path.join(tmpdir(),'usage-desk-installer-check-'));
// All platform, build, signature, and network tools are synthetic. No real app is built or launched.
const stub=`#!/bin/sh
set -eu
name=\${0##*/}
printf '%s %s\\n' "\$name" "\$*" >> "\$TEST_LOG"
case "\$name" in
 uname) if [ "\$TEST_CASE" = unsupported-os ]; then printf 'Linux\\n'; else printf 'Darwin\\n'; fi ;;
 id) if [ "\$TEST_CASE" = root ]; then printf '0\\n'; else printf '501\\n'; fi ;;
 sw_vers) if [ "\$TEST_CASE" = old-macos ]; then printf '13.7\\n'; else printf '15.0\\n'; fi ;;
 xcode-select) [ "\$TEST_CASE" != missing-toolchain ] ;;
 xcrun) if [ "\$TEST_CASE" = old-swift ]; then printf 'Apple Swift version 5.10\\n'; else printf 'Apple Swift version 6.0\\n'; fi ;;
 git)
  shift 2
  case "\$1" in
   fetch) [ "\$TEST_CASE" != fetch-failed ] ;;
   rev-parse) if [ "\$TEST_CASE" = wrong-commit ]; then printf 'wrong\\n'; else printf '${commit}\\n'; fi ;;
  esac ;;
 zsh)
  [ "\$TEST_CASE" != build-failed ] || exit 1
  source_dir=\${1%/scripts/build.sh}
  mkdir -p "\$source_dir/dist/Usage desk.app/Contents/MacOS"
  printf 'synthetic app\\n' > "\$source_dir/dist/Usage desk.app/Contents/MacOS/ResetDesk" ;;
 codesign) [ "\$TEST_CASE" != bad-signature ] ;;
 ditto)
  if [ "\$TEST_CASE" = copy-failed ]; then touch "\$2/partial"; exit 1; fi
  cp -R "\$1/." "\$2/" ;;
esac
`;
let checked=0;
try {
 const bin=path.join(temp,'bin');await mkdir(bin);
 for(const tool of ['uname','id','sw_vers','xcode-select','xcrun','git','zsh','codesign','ditto']){
  const file=path.join(bin,tool);await writeFile(file,stub);await chmod(file,0o755);
 }
 for(const scenario of ['success','unsupported-os','root','old-macos','missing-toolchain','old-swift','existing-app','existing-symlink','fetch-failed','wrong-commit','build-failed','bad-signature','copy-failed']){
  const base=path.join(temp,scenario);const home=path.join(base,'home with spaces');const scratch=path.join(base,'scratch');
  await mkdir(home,{recursive:true});await mkdir(scratch);const log=path.join(base,'tools.log');await writeFile(log,'');
  const app=path.join(home,'Applications','Usage desk.app');
  if(scenario==='existing-app'){
   await mkdir(app,{recursive:true});await writeFile(path.join(app,'keep'),'existing installation');
  }
  if(scenario==='existing-symlink'){
   await mkdir(path.dirname(app),{recursive:true});
   // A dangling symlink must be treated as an existing installation too.
   const {symlink}=await import('node:fs/promises');await symlink(path.join(base,'missing'),app);
  }
  const r=spawnSync('/bin/sh',[],{input:installer,encoding:'utf8',timeout:15000,env:{...process.env,PATH:bin+':/usr/bin:/bin',HOME:home,TMPDIR:scratch,TEST_CASE:scenario,TEST_LOG:log}});
  assert.equal(r.status,scenario==='success'?0:1,`${scenario}: ${r.stderr}`);
  const calls=await readFile(log,'utf8');
  if(scenario==='success'){
   assert.equal(await readFile(path.join(app,'Contents/MacOS/ResetDesk'),'utf8'),'synthetic app\n');
   assert.ok(calls.includes(`fetch -q --depth 1 origin ${commit}`));
   assert.ok(r.stdout.includes('Installed: '+app));
  } else if(scenario==='existing-app'){
   assert.equal(await readFile(path.join(app,'keep'),'utf8'),'existing installation');
   assert.ok(!calls.includes('git '));
  } else if(scenario!=='existing-symlink'){
   await assert.rejects(readFile(path.join(app,'Contents/MacOS/ResetDesk')));
   if(scenario==='copy-failed')await assert.rejects(readdir(app),'Remove a failed partial installation');
  }
  if(['unsupported-os','root','old-macos','missing-toolchain','old-swift','existing-symlink'].includes(scenario))assert.ok(!calls.includes('git '),`${scenario}: must not fetch source`);
  if(['fetch-failed','wrong-commit'].includes(scenario))assert.ok(!calls.includes('zsh '),`${scenario}: must not build unverified source`);
  assert.deepEqual(await readdir(scratch),[],`${scenario}: temporary source must be cleaned up`);
  checked++;
 }
 console.log(`Passed ${checked} isolated installer scenarios (no network, credentials, or real app installation).`);
} finally {await rm(temp,{recursive:true,force:true})}
