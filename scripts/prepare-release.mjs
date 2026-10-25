import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
assert.ok(args.length === 0 || (args.length === 1 && args[0] === '--website'), 'Usage: node scripts/prepare-release.mjs [--website]');
const git = (...args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim();
assert.equal(git('status', '--porcelain'), '', 'Commit and review changes before preparing a release.');
const version = (await readFile(path.join(root, 'VERSION'), 'utf8')).trim();
assert.match(version, /^\d+\.\d+\.\d+$/);
const commit = git('rev-parse', 'HEAD');
assert.match(commit, /^[a-f0-9]{40}$/);
assert.equal(git('show', `${commit}:VERSION`), version);
const tag = `v${version}`;
if (process.env.GITHUB_REF?.startsWith('refs/tags/')) assert.equal(process.env.GITHUB_REF, `refs/tags/${tag}`, 'Tag must match VERSION.');
const notes = await readFile(path.join(root, 'docs/releases', `${tag}.md`), 'utf8');
let installer = await readFile(path.join(root, 'website/install.sh'), 'utf8');
assert.match(installer, /source_commit=[a-f0-9]{40}/, 'Missing source pin.');
installer = installer.replace(/source_commit=[a-f0-9]{40}/, `source_commit=${commit}`);
if (/source_version=\d+\.\d+\.\d+/.test(installer)) installer = installer.replace(/source_version=\d+\.\d+\.\d+/, `source_version=${version}`);
else installer = installer.replace(`source_commit=${commit}`, `source_commit=${commit}\n    source_version=${version}`);
const manifest = { repository: 'https://github.com/NiKHiLkr23/usage-desk', version, tag, sourceCommit: commit };
const manifestText = JSON.stringify(manifest, null, 2) + '\n';
const output = path.join(root, 'dist/releases', tag);
await mkdir(output, { recursive: true });
const files = new Map([['install.sh', installer], ['release.json', manifestText], ['RELEASE_NOTES.md', notes]]);
for (const [name, contents] of files) await writeFile(path.join(output, name), contents);
await writeFile(path.join(output, 'SHA256SUMS'), [...files].map(([name, contents]) => `${createHash('sha256').update(contents).digest('hex')}  ${name}\n`).join(''));
if (args.includes('--website')) {
  await writeFile(path.join(root, 'website/install.sh'), installer);
  await writeFile(path.join(root, 'website/release.json'), manifestText);
  console.log(`Website installer now targets reviewed source ${commit}. Commit these distribution-only changes separately.`);
}
console.log(`Prepared ${tag} at ${commit} in dist/releases/${tag}. Source installer, metadata, checksums, and notes only; no tag, upload, or publication.`);
