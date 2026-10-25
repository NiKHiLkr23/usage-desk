# Releasing Usage Desk

Distribution is source only. Publishing a release does not require an Apple Developer account.
The native app retains its existing bundle ID and local credential paths between releases.

## Version and local review

`VERSION` is the shared semantic version. To bump it:

```sh
node scripts/version.mjs 0.1.1
npm run version:check
```

The command synchronizes package metadata, the app plist, website structured data, and its exact CSP hash.
Increment `CFBundleVersion` in `Support/Info.plist` for a new build. Keep this internal build identifier out of user-facing version labels; Preferences displays only the version.
Codex's initialization handshake uses the bundled app version. Direct SwiftPM runs report development.
Keep `CHANGELOG.md` and `docs/releases/v<VERSION>.md` current.

```sh
swift test --scratch-path .build --cache-path .cache
zsh scripts/build.sh
npm run check
npm run release:check
```

Normal tests use synthetic data and skip real accounts. Verify Apple silicon and Intel in CI before
claiming cross-architecture validation. Never stage credentials, private emails, raw auth URLs, local
account metadata, `.build/`, `.cache/`, `dist/`, or the installed app.

## Prepare the source release

Start from a clean, reviewed commit containing the final native app and release notes:

```sh
npm run release:prepare
```

This writes four text assets under ignored `dist/releases/v<VERSION>/`: `install.sh`, `release.json`,
`RELEASE_NOTES.md`, and `SHA256SUMS`. The installer is pinned to the full source commit, not a moving
branch. Preparation refuses uncommitted changes and mismatched CI tags. It does not tag, upload,
commit, push, deploy, or publish. GitHub automatically supplies source ZIP/tar archives for a tag.
Those archives are source, not installable app binaries.

To prepare the website's copy of the exact same installer and manifest:

```sh
node scripts/prepare-release.mjs --website
node scripts/check-website.mjs
```

Review and commit these distribution-only changes separately. The `sourceCommit` in
`website/release.json` identifies the app release checkpoint; it may precede later website-only commits.
If app source changes after preparation, commit and review those changes, then prepare a new pin.
Do not hand-edit a guessed SHA or point the installer at a branch.

## Tag and draft on GitHub

After local review and source-publication approval, push the branch and land the reviewed work.
Create an annotated `v<VERSION>` tag at the exact reviewed source commit recorded in the manifest,
then push that tag. A clean merge should retain the reviewed source checkpoint; if history is rewritten,
review and regenerate the pin for the actual source snapshot before creating the tag.

The tag-triggered `.github/workflows/release.yml` reuses the native CI checks, verifies the version,
generates text-only source assets, and creates a **draft** GitHub release. Its write permission is
limited to the draft job. It refuses to overwrite an existing release. No app binary or Apple
credential is uploaded. A CI failure prevents draft creation.

Review the draft notes, tag target, text-asset checksums, and clean-Mac source installation before
publishing the draft. Deploy the reviewed website installer separately, ensuring it targets the same
source SHA. Verify HTTPS `/install.sh` returns the reviewed text with revalidation and noindex headers.
Do not claim a release is public merely because its notes or version metadata exist in Git.

## Installer behavior and updates

The installer requires macOS 14+, Swift 6+ and Xcode Command Line Tools, fetches and verifies an
exact source SHA and version, builds locally, verifies the local signature before and after copying,
and installs into `~/Applications` without sudo. It refuses existing app paths, including symlinks.
To update, quit and move only the old `.app` to Trash, then rerun the installer. Account data and
provider CLI profiles remain in their existing directories; never delete a CLI home to update the app.

The script cleans temporary source and failed partial copies. Build output goes to a private log,
removed on success or retained with recent details on failure. Interactive runs offer app launch via
`/dev/tty`; redirected runs never launch it. It never installs the provider CLIs, authenticates accounts,
removes quarantine, disables Gatekeeper, or records installation/active-user analytics.
The synthetic installer checks do not prove clean-Mac compatibility; test that separately.

## Repository setup

Keep Issues and private vulnerability reporting available. Add relevant topics such as `macos`,
`swiftui`, `codex`, `claude`, and `menu-bar`. Require successful CI and PR review on `main` while
retaining a documented maintainer recovery route. Use existing bug/feature templates and focused
labels; `.github/release.yml` groups labeled PRs for generated notes. Contributors/languages update
automatically on GitHub. Packages are not required for this source-distributed Mac app.

## Optional local binary review

```sh
zsh scripts/package.sh --universal
```

This creates an ad-hoc-signed review ZIP and checksum under ignored `dist/releases/`. Do not attach
that build as a public installer or copy it into the website.

## Future signed and notarized distribution

This is a separate distribution decision. It requires Apple Developer membership, a Developer ID
Application identity, and an interactive `notarytool` Keychain profile. Never commit those credentials.

```sh
export USAGE_DESK_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
export USAGE_DESK_NOTARY_PROFILE='usage-desk-notary'
zsh scripts/package.sh --release
```

The explicit command builds universal, signs with hardened runtime, submits to Apple, staples and
validates the ticket, assesses the app, and produces a ZIP/checksum. It does not publish. Fix Apple
rejections rather than bypassing Gatekeeper. Source-only releases do not imply notarized binaries.

References: [GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases),
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
