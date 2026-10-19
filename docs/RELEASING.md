# Releasing Usage Desk

Nothing in this repository automatically creates a release, commits code, or deploys the website.
The project uses source-only distribution. The initial source publication and website deployment
were approved by the maintainer on 2026-10-18.
Publishing the source and website requires explicit approval and a public repository; Apple
Developer membership and signing credentials are not prerequisites for that source-only launch.

## Before the first push

- Review `REVIEW.md`, the MIT license/copyright, documentation, demo screenshots, and brand exports.
- Run native tests, website checks, a clean build, and a local install test on a spare/demo profile.
- Confirm `git status --short` contains only source and public assets. Never add `dist/`, `.build/`,
  `.cache/`, local downloads, credentials, or real account screenshots.
- Create the intended public `usage-desk` repository. Enable Issues, private vulnerability reporting,
  and PR checks. Keep default branch protection suitable for community contributions.
- Add a remote and commit/push **only after the maintainer approves the local review**.

## Review build (no upload)

```sh
zsh scripts/package.sh --universal
```

Produces `dist/releases/usage-desk-0.1.0-macos-<arch>.zip` plus SHA-256 checksum.
This is ad-hoc signed, not notarized, and remains under ignored `dist/releases/`. It is not copied
into the website or promoted as an installer. Previous website preview artifacts are preserved
under ignored `.local/`, outside the web root.

## Source-only launch

After maintainer approval, publish the repository with build instructions and configure only the
`repository` URL in `website/release.json`. Users obtain the source from GitHub and compile it on
their own Mac. The optional `website/install.sh` automates that local build and user-folder
installation; it is not a prebuilt installer. Keep the website explicit about Swift, macOS,
and Codex CLI requirements. Do not
attach ad-hoc-signed review builds as public installation assets.

## Future signed and notarized distribution

Prerequisites: Apple Developer membership, a Developer ID Application identity in Keychain,
Xcode's `notarytool`, and an existing `notarytool` Keychain credential profile. Set up the profile
interactively using Apple's documented workflow; do not store credentials in the repo or shell scripts.
The native app is not sandboxed and must be able to launch the installed Codex CLI.

```sh
export USAGE_DESK_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
export USAGE_DESK_NOTARY_PROFILE='usage-desk-notary'
zsh scripts/package.sh --release
```

This explicit release command builds a universal binary, signs with hardened runtime, submits the
app ZIP to Apple, staples the ticket, validates it and assesses the app, then creates the final ZIP
and checksum. It does not upload to GitHub or deploy. Inspect any Apple rejection and fix it rather
than bypassing Gatekeeper or disabling validation.

## Publish a future installer manually

After validation, create tag `v0.1.0` and a GitHub release with notes from `CHANGELOG.md`.
Attach only the final distribution ZIP and its checksum. Verify the download and signature on
another Mac; check Intel compatibility before claiming it has been tested. Add a new, explicitly
reviewed website download flow and deploy separately. The source-only website ignores binary
release fields. Never claim a CI-only build is notarized.

Official references:
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)

## Version changes

Update `CFBundleShortVersionString` and `CFBundleVersion` in `Support/Info.plist`, the protocol
client version in `CodexClient.swift`, `package.json` / lockfile, release notes, and website metadata
for each release. Keep the bundle identifier and credential directories stable unless migrating them.

## Maintaining the source installer

`website/install.sh` uses a full `source_commit` SHA rather than executing a moving branch.
It currently builds commit `9366db3b03b1fde7513e1f317e66e454f6d866d2` (native app version 0.1.0).
After reviewing and testing a future app source commit, update that pin and the expected commit
in `scripts/check-installer.mjs`, run the installer scenarios and website checks, and review
before publishing. The pinned source need not contain the installer itself.

The script installs into `~/Applications`, verifies the local signature before and after copying,
and refuses existing app paths, including symlinks. It cleans up temporary source and failed
partial copies. It does not launch the app, install the CLI/toolchain, change authentication,
remove quarantine attributes, or disable Gatekeeper. It requires network access to GitHub.
Users need the Codex CLI installed and signed in separately.

Before promoting the command publicly, test on a separate Mac with a supported toolchain and
verify `/install.sh` serves the reviewed script over HTTPS with plain-text content type. The
isolated test suite uses synthetic build/network/signature tools; it does not prove a clean-Mac
build or runtime compatibility. Never substitute an unsigned binary download under this command.
