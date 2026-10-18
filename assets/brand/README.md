# Usage Desk brand assets

Original vector reconstruction of the approved two-window concept: charcoal window outlines,
a solid green first progress segment, and two empty outlined segments. MIT licensed with the project.

## Files

- `mark-{light,dark,mono}.svg`: editable standalone symbol; transparent outside the windows.
- `logo-{horizontal,stacked}-{light,dark,mono}.svg`: symbol and wordmark lockups.
- PNG exports: transparent 128/256/512/1024-width marks and 1600-width lockups.
- JPEG lockups: opaque light/dark presentation backgrounds.
- `app-icon.svg`, `app-icon-1024.png`, `UsageDesk.icns`: padded native app icon.
- `favicon.svg`, `favicon.ico`, PNG sizes: website/tab/touch assets.
- `social-preview.{svg,png,jpg}`: 1200 × 630 sharing artwork.

The mark contains vector geometry only. Wordmark SVGs keep editable text with Arial/Helvetica/
sans-serif fallbacks; no font files are redistributed. PNGs freeze the rendered typography.
The app retains its text-only panel header; the logo is used for its bundle icon and website.

## Tokens

| Token | Light | Dark |
| --- | --- | --- |
| Ink | `#171717` | `#f4f4f4` |
| Interior | `#ffffff` | `#171717` |
| Green | `#577b45` | `#c9e6b9` |

Preserve frame spacing, corner geometry, and the three equal-width usage segments.
Use the reversed mark on dark backgrounds. Do not stretch the logo, add extra colored segments,
or place it over a busy photograph. Use the symbol alone at small sizes; test at 16/24/32 px.

## Regenerate

```sh
npm ci
npm run assets
```

Runs locally, requires Node 22+ and the optional development dependency `sharp`; macOS `iconutil`
creates the `.icns`. The app and website never load sharp at runtime. The SVG geometry is declared
in `scripts/generate-assets.mjs`; change it once, then regenerate matching exports.
