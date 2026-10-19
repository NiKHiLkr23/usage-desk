# Usage Desk landing page

Buildless HTML, CSS, and JavaScript. No framework, external fonts, analytics, or runtime dependencies.
The hero uses native captures rendered from the actual SwiftUI app views with isolated sample accounts.
No hand-built or AI-generated product mockups are used. The caption discloses sample data; the presentation-only Demo badge is omitted from captures.
All links and interactions must remain usable with keyboard and reduced motion.

## Local preview

```sh
npm run preview
```

The server binds only `127.0.0.1:4320`; set `PORT` to change the port. It serves only `website/`.
Run `node scripts/check-website.mjs` for structural, SEO, link, and privacy checks.
The preview reads production security headers from `vercel.json` and serves the real 404 page.
Vercel hostname redirects must be checked on the deployed site. Native app tests are separate.

## Source-only distribution

The GitHub actions link directly to [NiKHiLkr23/usage-desk](https://github.com/NiKHiLkr23/usage-desk)
in a new tab, including with JavaScript disabled. The same verified repository URL is recorded in
`release.json` for tooling. The website does not fetch release metadata. No app installer or preview
ZIP is promoted, on localhost or in production.

`install.sh` is a POSIX shell source installer, served as plain text with `noindex` and
revalidation headers. It fetches a fixed public Git commit, verifies it, builds with the
user's Swift toolchain, and installs into `~/Applications`. It requires macOS 14+ and
Swift 6+, refuses root and existing apps, and never installs Codex or changes Gatekeeper.
The terminal flow displays a compact text logo and real build/install phases. Build output
is saved to a private log, retained with recent details on failure and removed on success.
Interactive runs offer to open the app via `/dev/tty`; redirected runs never launch it.
`NO_COLOR`, plain-text link fallbacks, and a manual app-opening path are supported.
Run `node scripts/check-installer.mjs` for isolated, network-free installer checks.

The optional maintainer command `zsh scripts/package.sh --universal` creates a local review ZIP
under ignored `dist/releases/` only. It does not copy app binaries into the website. Previous
website review downloads were preserved outside the web root under ignored `.local/`.

## Design

The page uses a neutral palette, a single Helvetica Neue type family with local fallbacks,
and the real app capture as its main visual. Interface icons are limited to meaningful actions: theme, copy, and GitHub star. The setup sequence is numbered because its order matters; feature labels are not.
Keyboard focus, 44px controls, system appearance, and reduced motion are retained.

## Vercel deployment

Production: https://usage-desk.nikhilkr.in/ on the maintainer’s personal Vercel team.
The `usage-desk` project is connected to GitHub with Root Directory `website`.

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
3. Update canonical, social cards, structured data, robots, sitemap URLs, and redirects together if the production domain changes. See [search setup](../docs/SEARCH.md) for validation and account-side indexing steps.
4. Upload only the contents of `website/` excluding `downloads/` and this README to your static host.
5. Check the source/build actions, brand downloads, mobile layout, theme, FAQ, and privacy links.

A future signed/notarized installer is a separate distribution decision. It requires explicitly
adding and validating a download flow; metadata alone cannot enable one.

The maintainer approved source publication and website deployment on 2026-10-18. App installer
releases are separate decisions. The maintainer connected the custom domain on 2026-10-19. See [release instructions](../docs/RELEASING.md).

## Hero interactions

The install command is selectable with JavaScript disabled. JavaScript enables its copy button,
with success feedback and a selection/manual-copy fallback when clipboard access is denied.
The GitHub star action opens the repository; the site does not star automatically or show a fabricated count.

The preview uses keyboard-accessible Usage, Accounts, and Resets tabs with real native view
captures. Without JavaScript, the Usage image remains visible. All three images have equal
dimensions, so changing tabs does not resize the page. See `DESIGN.md` for the interaction decisions.

Regenerate the showcase captures on macOS with `zsh scripts/capture-website.sh`. The tool
uses the native views from the current committed source, changes only its temporary entry
point, and runs `AccountStore(demo: true)` in a temporary process. It never opens the live app
or reads real account storage. The output is 840 × 1000 PNG at 2× scale. Inspect all images
before publishing. The capture tool omits the presentation-only Demo badge in its temporary
source copy; sample data and all demo safety guards stay active. The installed app is unchanged.
