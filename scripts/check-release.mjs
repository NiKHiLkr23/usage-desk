import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, copyFile, readFile, writeFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temp = await mkdtemp(path.join(tmpdir(), 'usage-desk-release-check-'));
const env = { ...process.env, GIT_AUTHOR_NAME: 'Fixture', GIT_COMMITTER_NAME: 'Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.test', GIT_COMMITTER_EMAIL: 'fixture@example.test' };
delete env.GITHUB_REF;
const run = (cmd, args, overrides = {}) => spawnSync(cmd, args, { cwd: temp, env: { ...env, ...overrides }, encoding: 'utf8' });
const git = (...args) => {
  const result = run('git', args);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
};
try {
  await mkdir(path.join(temp, 'scripts'));
  await mkdir(path.join(temp, 'website'));
  await mkdir(path.join(temp, 'docs/releases'), { recursive: true });
  await copyFile(path.join(root, 'scripts/prepare-release.mjs'), path.join(temp, 'scripts/prepare-release.mjs'));
  await writeFile(path.join(temp, 'VERSION'), '0.1.1\n');
  await writeFile(path.join(temp, '.gitignore'), 'dist/\n');
  const installer = await readFile(path.join(root, 'website/install.sh'), 'utf8');
  await writeFile(path.join(temp, 'website/install.sh'), installer);
  await writeFile(path.join(temp, 'website/release.json'), '{"repository":"https://github.com/NiKHiLkr23/usage-desk"}\n');
  await writeFile(path.join(temp, 'docs/releases/v0.1.1.md'), '# Fixture release\n');
  git('init', '-q');
  git('config', 'core.hooksPath', '/dev/null');
  git('add', '.');
  git('-c', 'commit.gpgsign=false', 'commit', '-qm', 'Synthetic release fixture');
  const sha = git('rev-parse', 'HEAD');
  const prepare = (args = [], overrides = {}) => run(process.execPath, ['scripts/prepare-release.mjs', ...args], overrides);
  const success = prepare();
  assert.equal(success.status, 0, success.stderr);
  const output = path.join(temp, 'dist/releases/v0.1.1');
  assert.deepEqual((await readdir(output)).sort(), ['RELEASE_NOTES.md', 'SHA256SUMS', 'install.sh', 'release.json'].sort(), 'Only reviewed text assets; no binary upload');
  const generated = await readFile(path.join(output, 'install.sh'), 'utf8');
  assert.ok(generated.includes(`source_commit=${sha}`));
  assert.ok(generated.includes('source_version=0.1.1'));
  const manifest = JSON.parse(await readFile(path.join(output, 'release.json'), 'utf8'));
  assert.equal(manifest.sourceCommit, sha);
  assert.equal(manifest.tag, 'v0.1.1');
  assert.equal(await readFile(path.join(temp, 'website/install.sh'), 'utf8'), installer, 'Ordinary preparation leaves public installer unchanged');
  assert.equal(git('status', '--porcelain'), '', 'Preparation never tags or changes tracked files');
  assert.equal(git('tag', '--list'), '');
  for (const row of (await readFile(path.join(output, 'SHA256SUMS'), 'utf8')).trim().split('\n')) {
    const [digest, name] = row.split('  ');
    assert.match(name, /^(install\.sh|release\.json|RELEASE_NOTES\.md)$/);
    assert.equal(createHash('sha256').update(await readFile(path.join(output, name))).digest('hex'), digest);
  }
  const wrongTag = prepare([], { GITHUB_REF: 'refs/tags/v9.9.9' });
  assert.notEqual(wrongTag.status, 0, 'Refuse a release tag that disagrees with VERSION');
  await writeFile(path.join(temp, 'VERSION'), '0.1.2\n');
  assert.notEqual(prepare().status, 0, 'Refuse an uncommitted source snapshot');
  await writeFile(path.join(temp, 'VERSION'), '0.1.1\n');
  const promote = prepare(['--website']);
  assert.equal(promote.status, 0, promote.stderr);
  assert.equal(await readFile(path.join(temp, 'website/install.sh'), 'utf8'), generated);
  assert.deepEqual(git('diff', '--name-only').split('\n').sort(), ['website/install.sh', 'website/release.json']);
  console.log('Passed source-release checks: exact commit and version, checksums, text-only assets, dirty-tree/tag rejection, and isolated website promotion.');
} finally {
  await rm(temp, { recursive: true, force: true });
}
