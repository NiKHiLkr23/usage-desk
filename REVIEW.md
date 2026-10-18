# Publication review

Scope: the standalone Usage Desk native macOS app, buildless website, public screenshots,
brand assets, community documentation, and CI configuration. The initial review covered all
122 publishable files before any commit existed. The portfolio repository is separate.

The maintainer approved source publication and website deployment on 2026-10-18.
The public repository is https://github.com/NiKHiLkr23/usage-desk. Distribution is source-only;
there is no public app installer, Developer ID signing, notarized release, or automatic binary upload.

## Privacy and security

- No credential files, private-key blocks, GitHub/OpenAI token patterns, personal paths, or personal
  email addresses were found in the publishable files. Synthetic accounts use example domains.
- The original unredacted screenshot was never copied into the repository. The public capture
  permanently replaces its email; pixels outside that field match the original. App captures have
  no metadata. Brand rasters contain only image-format metadata such as DPI/JFIF.
- Inspected 42 raster images and all 47 entries of the downloadable brand archive. No private
  files, absolute paths, path traversal entries, or symbolic links were included.
- Builds, caches, local review archives, environment files, auth/account JSON, and signing
  credentials are excluded by Git. Local app archives stay outside the web root.
- Repository-local author and committer identities use the verified GitHub noreply email.
  No personal-email commits existed, so no history rewrite was necessary.
- Sign-in URLs require allowed OpenAI HTTPS origins. Raw backend errors are masked, login
  attempts are correlated, and added accounts have separate local Codex homes.
- The bridge allows account reads, usage reads, and explicit login operations. It does not
  run model turns, redeem resets, or replace the active Codex desktop/CLI login.
- Credentials are managed locally by Codex; this app does not promise Keychain-only storage.
  It is not a security boundary against other software running as the same macOS user.

## Verification

- Native suite: 24 passed, 2 optional live-account checks skipped (26 total).
- Universal release build: arm64 and x86_64 compiled; local ad-hoc signature verified.
- Website checks: 207 structural, local-link, repository, and publishable-file checks passed.
- JavaScript syntax and build/package script syntax checks passed.
- npm lockfile audit: zero reported vulnerabilities. No third-party Swift packages are used.
- Website GitHub actions use direct static links and work without JavaScript. No binary-download
  promotion remains. Previous preview metadata and app ZIP routes return 404.
- The docs describe source-only installation and the existing native account/storage boundaries.

## Verification limits

Browser automation was disabled in Work settings during review, so automated visual desktop/mobile
QA was unavailable. The maintainer reviewed the local preview and supplied the real app capture.
Live authentication, Developer ID signing/notarization, and cross-device installation were not run.
GitHub CI and Vercel host behavior must be checked after publication; local tests do not certify them.

See [README](README.md), [Privacy](docs/PRIVACY.md), [Security](SECURITY.md),
[Release guide](docs/RELEASING.md), and [Website](website/README.md).
