import { createRequire } from 'node:module';
import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// Normal checkout: npm install. A runtime module directory is optional for local tooling.
const require = createRequire(import.meta.url);
const sharp = require(process.env.USAGE_DESK_SHARP_PATH || 'sharp');
const out = path.join(root, 'assets/brand');
await mkdir(out, { recursive: true });
const theme = {
  light: { ink: '#171717', paper: '#ffffff', green: '#577b45' },
  dark: { ink: '#f4f4f4', paper: '#171717', green: '#c9e6b9' },
  mono: { ink: '#171717', paper: '#ffffff', green: '#171717' }
};
const shapes = ({ ink, paper, green }) => `
  <rect x="24" y="20" width="146" height="100" rx="16" fill="${paper}" stroke="${ink}" stroke-width="6"/>
  <rect x="62" y="56" width="154" height="108" rx="16" fill="${paper}" stroke="${ink}" stroke-width="6"/>
  <rect x="80" y="108" width="34" height="10" rx="5" fill="${green}"/>
  <rect x="122" y="109" width="32" height="8" rx="4" fill="${paper}" stroke="${ink}" stroke-width="2"/>
  <rect x="164" y="109" width="32" height="8" rx="4" fill="${paper}" stroke="${ink}" stroke-width="2"/>`;
const svg = (viewBox, body, title = 'Usage Desk') => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" role="img" aria-labelledby="title"><title id="title">${title}</title>${body}</svg>`;
for (const [name, colors] of Object.entries(theme)) {
  const mark = svg('0 0 240 184', shapes(colors));
  await writeFile(path.join(out, `mark-${name}.svg`), mark);
  for (const width of [128, 256, 512, 1024]) {
    await sharp(Buffer.from(mark)).resize({ width }).png().toFile(path.join(out, `mark-${name}-${width}.png`));
  }
  const horizontal = svg('0 0 590 184', `${shapes(colors)}<text x="254" y="119" fill="${colors.ink}" font-family="Arial, Helvetica, sans-serif" font-size="57" font-weight="600" letter-spacing="-2">usage desk</text>`);
  const stacked = svg('0 0 360 360', `<g transform="translate(60 20)">${shapes(colors)}</g><text x="180" y="276" text-anchor="middle" fill="${colors.ink}" font-family="Arial, Helvetica, sans-serif" font-size="43" font-weight="600" letter-spacing="-1.5">usage desk</text>`);
  for (const [layout, artwork] of [['horizontal', horizontal], ['stacked', stacked]]) {
    await writeFile(path.join(out, `logo-${layout}-${name}.svg`), artwork);
    await sharp(Buffer.from(artwork)).resize({ width: 1600 }).png().toFile(path.join(out, `logo-${layout}-${name}.png`));
    await sharp(Buffer.from(artwork)).resize({ width: 1600 }).flatten({ background: colors.paper }).jpeg({ quality: 94 }).toFile(path.join(out, `logo-${layout}-${name}.jpg`));
  }
}
const icon = svg('0 0 1024 1024', `<rect x="64" y="64" width="896" height="896" rx="204" fill="#ffffff"/><g transform="translate(154 238) scale(3)">${shapes(theme.light)}</g>`);
await writeFile(path.join(out, 'app-icon.svg'), icon);
const iconset = path.join(root, 'dist/UsageDesk.iconset');
await mkdir(iconset, { recursive: true });
for (const size of [16, 32, 128, 256, 512]) {
  for (const scale of [1, 2]) {
    const px = size * scale;
    await sharp(Buffer.from(icon)).resize(px, px).png().toFile(path.join(iconset, `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`));
  }
}
await sharp(Buffer.from(icon)).resize(1024, 1024).png().toFile(path.join(out, 'app-icon-1024.png'));
if (process.platform === 'darwin') execFileSync('iconutil', ['-c', 'icns', iconset, '-o', path.join(out, 'UsageDesk.icns')]);
const favicon = svg('0 0 240 240', `<rect width="240" height="240" rx="48" fill="#ffffff"/><g transform="translate(0 28)">${shapes(theme.light)}</g>`);
await writeFile(path.join(out, 'favicon.svg'), favicon);
for (const size of [16, 32, 180, 192, 512]) await sharp(Buffer.from(favicon)).resize(size, size).png().toFile(path.join(out, `favicon-${size}.png`));
const icoImages = await Promise.all([16,32,48].map(size => sharp(Buffer.from(favicon)).resize(size,size).png().toBuffer()));
const header = Buffer.alloc(6 + icoImages.length * 16); header.writeUInt16LE(1, 2); header.writeUInt16LE(icoImages.length,4);
let offset=header.length;
icoImages.forEach((png,i)=>{ const n=6+i*16; const size=[16,32,48][i]; header[n]=size; header[n+1]=size; header.writeUInt16LE(1,n+4); header.writeUInt16LE(32,n+6); header.writeUInt32LE(png.length,n+8); header.writeUInt32LE(offset,n+12); offset+=png.length; });
await writeFile(path.join(out,'favicon.ico'),Buffer.concat([header,...icoImages]));
const social=svg('0 0 1200 630', `<rect width="1200" height="630" fill="#f4f5f0"/><g transform="translate(78 86) scale(0.8)">${shapes(theme.light)}</g><text x="78" y="340" font-family="Arial, Helvetica, sans-serif" font-size="76" font-weight="700" letter-spacing="-4" fill="#171717">Your usage. At a glance.</text><text x="82" y="399" font-family="Arial, Helvetica, sans-serif" font-size="27" fill="#686868">Codex quotas, reset times, and accounts. In your Mac menu bar.</text><text x="82" y="542" font-family="Arial, Helvetica, sans-serif" font-size="28" font-weight="600" fill="#171717">usage desk</text><text x="1118" y="542" text-anchor="end" font-family="Arial, Helvetica, sans-serif" font-size="20" fill="#686868">Free &amp; open source</text>`);
await writeFile(path.join(out,'social-preview.svg'),social);
await sharp(Buffer.from(social)).png().toFile(path.join(out,'social-preview.png'));
await sharp(Buffer.from(social)).jpeg({quality:94}).toFile(path.join(out,'social-preview.jpg'));
for (const file of ['mark-light.svg','mark-dark.svg','logo-horizontal-light.svg','logo-horizontal-dark.svg','favicon.svg','favicon.ico','favicon-180.png','social-preview.png']) await copyFile(path.join(out,file),path.join(root,'website/assets',file));
console.log('Generated SVG, PNG, JPEG, ICO, and macOS ICNS assets.');
