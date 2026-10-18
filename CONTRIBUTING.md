# Contributing to Usage Desk

Bug reports, accessibility improvements, documentation, and focused pull requests are welcome.
Read the [code of conduct](CODE_OF_CONDUCT.md). For a substantial change, open a feature request
first so we can agree on the behavior before you spend time implementing it.

## Local setup

Use macOS 14+, Swift 6+, and Xcode Command Line Tools. No Swift package dependencies are required.
A real Codex CLI or account is not needed to run the ordinary tests.

```sh
zsh scripts/build.sh
swift test --scratch-path .build --cache-path .cache
node scripts/check-website.mjs
```

Swift modules retain the internal `ResetDesk` names for compatibility. The product is Usage Desk.
Use existing semantic colors and native control styles. Green is for quota, connection status,
and the brand indicator. Keep System as the default; honor Reduce Motion.

## Screenshot / demo mode

```sh
zsh scripts/build.sh --demo
open "dist/Usage Desk Demo.app"
```

This separate app uses synthetic `example.com` accounts, a separate preferences domain,
no Chrome profile reads, no Codex connections, and no account-file load or writes.
Use it to capture real app screenshots without private accounts. Regular builds never enable demo mode by default.
For an existing real screenshot, permanently redact personal fields and strip metadata before adding it.
See `assets/screenshots/README.md` and `scripts/sanitize-screenshot.py`; inspect every exported image.
Do not submit screenshots containing real emails, account IDs, auth links, or tokens.

## Optional live tests

These are explicitly opt-in, outside CI:

```sh
RESET_DESK_LIVE_CODEX=/absolute/path/to/codex swift test --filter LiveReadTests/testSignedInCodexCanReadUsage
RESET_DESK_LIVE_LOGIN=/absolute/path/to/codex swift test --filter LiveReadTests/testTwoLiveProfilesCanPrepareAndCancelLogin
```

The first reads the current local account. The second creates temporary isolated signed-out homes,
prepares/cancels/retries a login, and never opens a browser or completes OAuth. Neither starts a model turn
or redeems a reset. Complete real browser sign-in yourself when testing account connection.

## Website and assets

```sh
npm run preview
npm run check
```

No install or build step is needed to serve the website. To regenerate raster brand exports only,
install the development dependency with `npm ci`, then run `npm run assets` on macOS.
SVG sources are editable; exports are committed assets. See [the brand guide](assets/brand/README.md).

## Issues

Use the bug or feature template after the repository is public. Include the macOS version, app version,
architecture, Codex CLI version, and reproduction steps. Sanitize diagnostics. Never attach
`auth.json`, `accounts.json`, browser databases, your entire Codex home, or raw sign-in URLs.
Report suspected security issues [privately](SECURITY.md).

## Pull requests

Keep changes focused. Explain the user-visible behavior, why it changes, and how you verified it.
Include sanitized screenshots for UI changes and mention untested cases. Add a regression test
when it protects behavior; avoid tests that just duplicate implementation details.
Run the native tests and website checks appropriate to your change. CI runs without real credentials.
Use a regular fork and branch; maintainers review PRs before merge. No CLA is required;
contributions are made under the repository's MIT license.
