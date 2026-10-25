# Working in Usage Desk

This is a standalone native macOS menu bar app with a static landing page.
The existing bundle ID, internal ResetDesk module names, preference keys, and storage paths
are compatibility contracts. Avoid changing them without a migration.

## Layout and checks

- `Sources/ResetDesk`: SwiftUI views, AppKit presentation, AccountStore.
- `Sources/ResetDeskCore`: storage, JSON-RPC, models, login correlation.
- `website`: buildless landing page and interactive sample app preview.
- `assets/brand`: original vector masters and exported brand files.
- Native tests: `swift test --scratch-path .build --cache-path .cache`.
- Build: `zsh scripts/build.sh` (`--universal` and `--demo` are optional).
- Website/public-file checks: `node scripts/check-website.mjs`.
- Local website: `npm run preview` on loopback port 4320.

## Account boundaries

Do not read, stage, or publish real authentication files, raw sign-in URLs, account metadata,
or real-email screenshots. Use isolated demo mode and synthetic test fixtures. Normal tests
must not require credentials or network. Live tests are explicit opt-in only.
Do not change the current Codex desktop/CLI login while working on Usage Desk.

## UI and contributions

Reuse semantic colors and native component styles. Preserve System theme as default,
Reduce Motion support, full-row account hit targets, and draft/login lifetime on dismissal.
The Accounts tab is a compact selector; Manage/Add account expand the same panel.
The original logo has one green first segment and two empty outlined segments.
The website uses an HTML/CSS/JS app preview, explicitly approved on 2026-10-25. Match native tokens and interactions, disclose sample data, and keep it isolated from real accounts. Omit sign-in, Add account, removal, CLI paths, and OS-only controls. Theme controls share one System-first setting across the page and preview. Repository screenshots must remain real app captures with permanently redacted fields and stripped metadata; do not use generated product imagery.

Follow the current user's publication instructions. The maintainer approved the initial source
commit, GitHub push, and website deployment on 2026-10-18. App binaries, signing credentials,
and installer releases are outside this source-only publication.

Current distribution is source-only. Website actions must lead to build instructions or the verified
public repository. Do not promote app binaries or copy review ZIPs into the website.
