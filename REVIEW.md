# Release review — 0.1.1

**NOT VERIFIED** — no confirmed source-code release blocker was found in this review, but
live CLI compatibility, a fresh-Mac installation, and Vercel Analytics activation still need
release-time verification. Local checks do not establish those production behaviors.

Reviewed 2026-10-25: `codex/v0.1.1-refactor` through `fbeedce`, compared with merge-base
`838fd7219fe9db38f56427e3d426f872f245934a` of the locally known `origin/main`. No fetch was
performed. Scope includes the 88 changed files, their native/account callers, source-release
and CI configuration, and the 161 publishable files. The implementation was committed before
the final review; only this report is added afterward. The portfolio repository is outside scope.

The app source checkpoint is `53883b436afb1e506be9d4832be580a3cf4860a5`, version 0.1.1,
build 2. `website/install.sh` and `website/release.json` agree on that checkpoint. Distribution
remains source-only: local compilation and ad-hoc signing, with no public app binary,
Developer ID identity, notarization, or Gatekeeper changes. The production domain is
https://usage-desk.nikhilkr.in/; deployment of this branch has not been performed.

## Issues

None found in the reviewed source. No confirmed credential leak, authentication replacement,
model-prompt execution, or destructive account operation was identified in the changed paths.
Pattern scans are evidence for the scanned files and patterns, not proof against every possible leak.

Privacy and security boundaries checked:

- Publishable text and the local branch diff history contained no matches for the scanned
  private-key, GitHub/OpenAI/Anthropic/AWS credential, personal-email, or personal-path patterns.
  Branch author/committer emails use the repository's GitHub noreply identity. Real authentication
  files and account storage were not opened or staged.
- Existing account records without a provider still decode as Codex. Unknown provider values fail
  decoding. Renaming validates labels and preserves account IDs, homes and credentials; removing a
  profile retains the provider's local sign-in. The existing bundle ID and storage keys are unchanged.
- Claude reads are limited to initialize/get_usage with no user message. The probe disables tools,
  hooks, MCP, optional transcript scanning, session persistence and optional reporting; it uses a
  private temporary working directory, sanitized failures, correlated responses and request timeouts.
  Claude owns authentication and ordinary credential refresh. Its control protocol is experimental.
- Codex keeps its isolated browser sign-in flow. The app does not replace the active desktop/CLI
  account, send model turns or redeem reset credits. Successful connection navigation requires
  usable account/usage data and rejects a known email mismatch.
- The website preview uses fixed example.com accounts. Edited names are HTML-escaped and stay in
  memory, including unfinished drafts. No preview action reaches a CLI, credential store, provider,
  native app or analytics event. Add account, sign-in, removal, CLI paths and OS-only controls are omitted.
- Theme effects keep only temporary rendering snapshots. The native effect snapshots its own
  content view in memory, passes clicks through, and releases the overlay on completion, replacement,
  navigation or dismissal. No screenshot is saved or uploaded. Reduce Motion bypasses the effect.
- Website analytics is production-origin-only, respects DNT/GPC, filters page URLs, and keeps custom
  events disabled pending plan verification. The native app and installer have no install/usage telemetry.
  The site's CSP remains strict, with an updated exact JSON-LD hash and no unsafe-inline exception.
- Source installation still refuses root and existing apps, verifies the exact commit/version and
  local app signature, and cleans incomplete installations. No moving branch or binary download is executed.

## Improvements

None required for this scoped source change. Further provider capabilities, automatic updates,
app telemetry and signed binary distribution remain separate product decisions.

## Simplification opportunities

None requiring another refactor for this release. The former screenshot-tab controller and seven
public product PNGs were removed. A single web theme controller now drives the page and preview;
real repository screenshots remain separate. No framework or runtime dependency was added.

## Verification

Completed during implementation, before the final read-only review:

| Check | Evidence |
| --- | --- |
| `swift test --scratch-path .build --cache-path .cache` | 43 passed, 3 explicit live-account tests skipped; zero failures. |
| `zsh scripts/build.sh --universal` | Apple Silicon and Intel release build succeeded. |
| `lipo -archs` and `codesign --verify --strict` on the built app | arm64 + x86_64; local ad-hoc signature verified. |
| `node scripts/check-website.mjs` | 360 structural, SEO, local-link, metadata and publishable-file checks passed across 161 public files. Includes JS syntax, analytics privacy checks and 23 isolated installer scenarios with no network or real installation. |
| `node scripts/check-release.mjs` | Passed synthetic source-pin/version/checksum, text-only output, dirty-tree/tag rejection and website-promotion scenarios. |
| `node scripts/version.mjs --check` | Version and structured-data/CSP metadata consistent. |
| Native AppKit motion probe | 41 presentation-layer samples, 31 distinct circle radii; rapid reversal kept at most one overlay, cleanup left zero, missing-anchor fallback applied. Synthetic window only. |
| Local browser interaction checks | Usage/Resets/Accounts, earned/scheduled resets, Codex/Claude selection, account settings, escaped name edits, Saved feedback, draft retention across Preferences, keyboard tab/menu controls and synchronized theme controls worked. Circular website reveal was observed. |
| Responsive/browser checks | Desktop and 375px viewport checked; narrow-layout overflow was corrected. No console warnings or errors observed on the final preview. Temporary viewport override was reset. |
| Publication hygiene | Publishable-file/history pattern scans found no matches; `git diff --check` passed. No production service, real account or personal screenshot was used for verification. |

Final review inspected the committed implementation and distribution-only source-pin change;
no tests, fixtures, source or dependencies were modified during that review phase. Earlier
implementation probes and existing test runners used disposable synthetic data. The report itself
does not change runtime behavior.

Remaining checks and decisions:

1. Finish the maintainer's native app test on the new build: appearance reveal in both directions,
   hover effects, rapid clicks, dismissal/reopen and Reduce Motion. The running app was not quit or
   replaced during this work; reopen the new build to load the added reveal.
2. Confirm current Codex and Claude CLI sign-in/usage behavior explicitly before release. Offline
   fixtures cannot establish compatibility with a particular installed CLI or live provider. No live
   account test was opted into here, and no active Codex/T3 login was changed.
3. Verify a clean source install on another supported Mac/toolchain. Both architectures compiled,
   but Intel execution and a fresh Mac installation were not performed. No new dependency audit
   service was contacted; the package still has no third-party Swift dependencies.
4. The circular website effect was exercised in the available browser. Reduce Motion and
   unsupported-API paths were inspected, but older Safari, VoiceOver and manual reduced-motion
   behavior have not been exercised in this pass. They should switch appearance immediately.
5. In Vercel's Usage Desk project, enable Web Analytics once if it is not already enabled, then
   deploy after approval. Check the insights script, an ordinary page view and the dashboard after
   deployment. Leave custom events off unless the existing plan supports them. Dashboard state
   and collection have not been verified. Visits are not confirmed installs or active app users.
6. Publication is pending maintainer approval: push this branch, create/review the PR, pass CI,
   merge to main and verify the resulting Vercel deployment. No push, PR, merge, tag, release,
   upload or deployment was performed for this change.

See [architecture](docs/ARCHITECTURE.md), [privacy](docs/PRIVACY.md),
[analytics setup](docs/ANALYTICS.md), [release guide](docs/RELEASING.md), and
[website interaction decisions](website/DESIGN.md).
