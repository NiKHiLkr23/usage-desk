# Usage Desk landing page

Buildless HTML, CSS, and JavaScript. No framework, external fonts, analytics, or runtime dependencies.
The hero uses an actual macOS app screenshot, with the account email anonymized.
No hand-built or AI-generated product mockups are used.
All links and interactions must remain usable with keyboard and reduced motion.

## Local preview

```sh
npm run preview
```

The server binds only `127.0.0.1:4320`; set `PORT` to change the port. It serves only `website/`.
Run `node scripts/check-website.mjs` for structural/link/privacy checks. Native app tests are separate.

## Source-only distribution

The GitHub actions link directly to [NiKHiLkr23/usage-desk](https://github.com/NiKHiLkr23/usage-desk)
in a new tab, including with JavaScript disabled. The same verified repository URL is recorded in
`release.json` for tooling. The website does not fetch release metadata. No app installer or preview
ZIP is promoted, on localhost or in production.

The optional maintainer command `zsh scripts/package.sh --universal` creates a local review ZIP
under ignored `dist/releases/` only. It does not copy app binaries into the website. Previous
website review downloads were preserved outside the web root under ignored `.local/`.

## Design

The page uses a neutral palette, a single Helvetica Neue type family with local fallbacks,
and the real app capture as its main visual. The only interface icon is the theme control. The setup sequence is numbered because its order matters; feature labels are not.
Keyboard focus, 44px controls, system appearance, and reduced motion are retained.

## Vercel deployment

Import the repository with **Root Directory `website`**. The included `vercel.json` selects
static hosting with no install/build command and output `.`. It adds a content security policy
and other browser headers. `404.html` provides a missing-page fallback.
`.vercelignore` excludes the local review downloads and this README. The root Git ignore also
keeps review ZIPs and metadata out of the repository. Vercel project linkage stays in ignored `.vercel/` metadata.

Use the domain records Vercel displays for your chosen subdomain. Do not assume a DNS target.
See [Vercel configuration](https://vercel.com/docs/project-configuration/vercel-json) and
[file exclusions](https://vercel.com/docs/deployments/vercel-ignore).

## Publication

1. Commit and push the reviewed source to the existing public repository after maintainer approval. No signed app release is required for source-only distribution.
2. Keep the static GitHub links and `repository` in `release.json` set to the verified repository URL.
3. Add the final absolute `og:url`, canonical URL, and absolute `og:image` URL when the domain is known.
4. Upload only the contents of `website/` excluding `downloads/` and this README to your static host.
5. Check the source/build actions, brand downloads, mobile layout, theme, FAQ, and privacy links.

A future signed/notarized installer is a separate distribution decision. It requires explicitly
adding and validating a download flow; metadata alone cannot enable one.

The maintainer approved source publication and website deployment on 2026-10-18. App installer
releases and a custom domain are separate decisions. See [release instructions](../docs/RELEASING.md).
