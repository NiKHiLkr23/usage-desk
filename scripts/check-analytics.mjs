import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = await readFile(path.join(root, 'website/analytics.js'), 'utf8');
const shipped = JSON.parse(await readFile(path.join(root, 'website/analytics-config.json'), 'utf8'));
assert.equal(typeof shipped.enabled, 'boolean');
assert.equal(shipped.customEvents, false, 'Keep paid custom events off until the hosting plan is verified.');
async function scenario({ origin = 'https://usage-desk.nikhilkr.in', dnt, gpc, config = shipped, fetchFails = false } = {}) {
  const scripts = [], listeners = new Map();
  let requests = 0;
  const window = { location: { origin } };
  const document = {
    head: { appendChild: script => scripts.push(script) },
    createElement: () => ({}),
    addEventListener: (name, callback) => listeners.set(name, callback),
  };
  vm.runInNewContext(source, { window, document, navigator: { doNotTrack: dnt, globalPrivacyControl: gpc }, URL,
    fetch: async () => { requests++; if (fetchFails) throw new Error('offline'); return { ok: true, json: async () => config }; },
  });
  await new Promise(resolve => setImmediate(resolve));
  return { window, scripts, listeners, requests };
}
for (const options of [
  { origin: 'http://127.0.0.1:4320' }, { origin: 'http://localhost:4320' },
  { origin: 'https://usage-desk-git-feature.vercel.app' },
  { origin: 'http://usage-desk.nikhilkr.in' }, { dnt: '1' }, { dnt: 'yes' }, { gpc: true },
]) {
  const result = await scenario(options);
  assert.equal(result.requests, 0, 'Privacy signals and non-production origins make no analytics requests.');
  assert.equal(result.scripts.length, 0);
}
assert.equal((await scenario({ config: { enabled: false } })).scripts.length, 0);
assert.equal((await scenario({ fetchFails: true })).scripts.length, 0);
const views = await scenario();
assert.equal(views.scripts[0].src, '/_vercel/insights/script.js');
assert.equal(views.listeners.size, 0, 'Basic measurement never attaches paid event collectors.');
const redact = views.window.vaq.find(([name]) => name === 'beforeSend')[1];
assert.equal(redact({ type: 'pageview', url: 'https://usage-desk.nikhilkr.in/privacy.html?email=private@example.test#token' }).url, 'https://usage-desk.nikhilkr.in/privacy.html');
assert.equal(redact({ type: 'pageview', url: 'https://usage-desk.nikhilkr.in/private-account-name' }).url, 'https://usage-desk.nikhilkr.in/404');
assert.equal(redact({ type: 'event', name: 'unknown-private-data' }), null);
assert.equal(JSON.stringify(redact({ type: 'event', name: 'Install command copied', url: '/', data: { placement: 'hero', email: 'private@example.test' } }).data), '{"placement":"hero"}');
const events = await scenario({ config: { enabled: true, customEvents: true } });
const copied = events.listeners.get('usage-desk:install-command-copied');
copied({ detail: { placement: 'hero', clipboard: 'private content' } });
copied({ detail: { placement: 'footer' } });
copied({ detail: { placement: 'private@example.test' } });
const clicked = events.listeners.get('click');
clicked({ target: { closest: () => ({ href: 'https://github.com/NiKHiLkr23/usage-desk' }) } });
clicked({ target: { closest: () => ({ href: 'https://other.example.test/private' }) } });
const tracked = JSON.parse(JSON.stringify(events.window.vaq.filter(([type]) => type === 'event')));
assert.deepEqual(tracked, [
  ['event', { name: 'Install command copied', data: { placement: 'hero' } }],
  ['event', { name: 'Install command copied', data: { placement: 'footer' } }],
  ['event', { name: 'GitHub opened' }],
]);
events.scripts[0].onerror();
assert.doesNotThrow(() => copied({ detail: { placement: 'hero' } }));
assert.equal(events.window.vaq.length, 0, 'A blocked SDK drops optional events without accumulating data.');
const app = await readFile(path.join(root, 'website/app.js'), 'utf8');
assert.ok(app.indexOf("document.dispatchEvent(new CustomEvent('usage-desk:install-command-copied'") > app.indexOf('await navigator.clipboard.writeText'), 'Only successful clipboard writes signal copies.');
console.log('Passed website analytics checks: production/privacy gates, URL redaction, plan-gated fixed events, copy success, and blocked-SDK recovery (no network).');
