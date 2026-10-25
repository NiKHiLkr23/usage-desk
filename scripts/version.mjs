import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const check = args.length === 1 && args[0] === '--check';
assert.ok(check || (args.length === 1 && /^\d+\.\d+\.\d+$/.test(args[0])), 'Usage: node scripts/version.mjs <major.minor.patch> | --check');
const version = check ? (await readFile(path.join(root, 'VERSION'), 'utf8')).trim() : args[0];
assert.match(version, /^\d+\.\d+\.\d+$/);
const outputs = [];
for (const name of ['package.json', 'package-lock.json']) {
  const filename = path.join(root, name);
  const source = await readFile(filename, 'utf8');
  const data = JSON.parse(source);
  data.version = version;
  if (name === 'package-lock.json') data.packages[''].version = version;
  outputs.push([filename, source, JSON.stringify(data, null, 2) + '\n']);
}
const plist = path.join(root, 'Support/Info.plist');
const original = await readFile(plist, 'utf8');
assert.match(original, /<key>CFBundleShortVersionString<\/key>\s*<string>[^<]+<\/string>/);
outputs.push([plist, original, original.replace(/(<key>CFBundleShortVersionString<\/key>\s*<string>)[^<]+/, `$1${version}`)]);
if (check) {
  for (const [filename, source, expected] of outputs) assert.equal(source, expected, `Version drift in ${path.relative(root, filename)}; run node scripts/version.mjs ${version}`);
  console.log(`Version ${version} is consistent across app and package metadata.`);
} else {
  await writeFile(path.join(root, 'VERSION'), version + '\n');
  for (const [filename, , source] of outputs) await writeFile(filename, source);
  console.log(`Set Usage Desk version to ${version}. Increment CFBundleVersion in Support/Info.plist for a new build.`);
}
