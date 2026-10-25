# Privacy

The native Usage Desk app has no hosted account system, telemetry, analytics, or crash-upload service.
The website has separate, cookie-free aggregate analytics; it never receives accounts from the app.

## What the app reads

- Account identity, plan, usage windows, and earned-reset information returned by Codex.
- Local account labels, selected account, appearance, refresh interval, and executable preference.
- Chrome's Local State profile names/emails to populate a browser picker. It does not read
  cookies, browsing history, passwords, or browser token databases.

## What is stored

The current CLI account stays in its existing Codex home (normally `~/.codex`). Added accounts
use `~/Library/Application Support/ResetDesk/accounts/<uuid>/`. Codex manages their authentication
and refresh credentials locally. Metadata is `accounts.json` in the parent support folder;
preferences use macOS UserDefaults. The app does not promise that credentials are stored in Keychain:
managed profiles explicitly request Codex's file credential store unless policy overrides it.

Removing a profile removes it from tracking; the authentication directory remains. To erase retained
credentials, first quit Usage Desk, identify the correct isolated directory, and remove it yourself.
Never delete your current Codex home merely to remove a Usage Desk profile.

## Network and browsers

The installed Codex CLI communicates with OpenAI for sign-in, token refresh, and usage reads.
OpenAI's policies apply to that traffic. The browser receives the validated OpenAI sign-in URL
in the profile you choose; the URL is kept in memory and can be copied explicitly. It may contain
sensitive authorization parameters—do not share it. The local callback is owned by Codex.
Usage Desk does not run model turns or consume earned resets.

The static website uses your browser's localStorage only for an optional theme preference.
Production-only Vercel Web Analytics can count aggregate visits and referrers after activation and
deployment. Its before-send hook removes query strings/fragments from page URLs and limits paths to
the public pages. Localhost, preview domains, Do Not Track and Global Privacy Control are excluded.
Custom events are disabled by default pending plan verification. If enabled, they send only fixed
event names and a hero/footer placement for successful command copies, never clipboard contents or
account data. The installer does not report success, and the app does not report active users.
See `docs/ANALYTICS.md` for activation and measurement limits.
A hosting provider may process ordinary access logs under its own policy. Release downloads
from GitHub are subject to GitHub's policies. The local preview does not contact GitHub or OpenAI.

## Public examples

Repository product images are actual app captures with the email permanently replaced by
`personal@example.com`; their metadata is stripped. Other usage values come from the capture.
The original unredacted image is not in the repository. The optional screenshot-mode app
uses synthetic accounts and never reads real accounts. Sanitize all screenshots and diagnostics
before contributing.

## Claude CLI accounts

Claude connections store the provider, a user-supplied label, and the selected existing CLI
configuration directory. The app does not read Claude credential files or browser cookies.
Claude CLI reads its own sign-in and communicates directly with Anthropic for usage. It may
perform its ordinary credential refresh. The app does not modify your Claude settings.

Usage probes never send a model prompt. `skip_behaviors: true` skips the optional transcript
scan. Only account identity, plan, reported quota percentages, and reset times are decoded
for display. Output remains in memory, subprocess stderr is discarded, temporary working
directories are removed, and backend failures use generic messages. Removing a profile
retains its CLI directory and sign-in.

## Interactive website preview and appearance effects

The website preview uses fixed example.com accounts. It has no authentication flow, provider
connection or app bridge. Sample display-name edits and preview settings stay in memory and reset
on reload. Neither labels nor preview interactions are sent to analytics. Only the optional website
theme is saved in localStorage; no app credentials or real account details are available to the page.

The native appearance reveal briefly snapshots only its own app content in memory. The snapshot
is not written to disk, logged or uploaded. The overlay is released after 480 ms, on a new change,
on navigation or panel dismissal. Reduce Motion bypasses the effect. Browser theme transitions use
the browser's own ephemeral rendering snapshots; no screenshot capture/download is performed.
