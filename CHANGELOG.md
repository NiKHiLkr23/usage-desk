# Changelog

## Unreleased — 0.1.1

- Fixed Light/Dark selection changing only the icon when the popover inherits a dark menu-bar appearance. Build 3 applies the choice to the owning window and SwiftUI colors.

- Fixed the native circular theme reveal disappearing during SwiftUI appearance updates; the overlay now uses a stable AppKit surface.

- Replaced website screenshots with an interactive native-style preview using isolated sample accounts, account settings and Preferences.
- Shared System-first website/preview appearance with a circular theme reveal; added the matching in-memory native effect with Reduce Motion and interruption support.

- A persistent selected-tab pill glides between items, including keyboard selection and Reduce Motion support.

- Account-settings gears and Preferences sliders move forward once on hover, hold their position, and reset on exit, with Reduce Motion support.

- Per-account editing with saved display names, a direct header shortcut, and retained CLI credentials on removal.
- Quick account rows open usage immediately and show quota/reset summaries; Add account preselects Codex or Claude.
- Successful connections open usage automatically; failed or mismatched connections stay in account management.
- Claude orange provider marks, semantic quota colors, and Command-1/2/3 and Command-comma navigation.

- Claude Pro/Max quota windows and reset times through an existing Claude CLI sign-in.
- Codex/Claude provider selection and provider icons throughout the account interface.
- Claude profile-directory and executable selection, including installations managed by nvm.
- Preserve macOS user context for Claude Keychain sign-in and permit usage reads while
  disabling telemetry, error reporting, feedback, and automatic updates.
- Keep provider icons at native menu size instead of displaying full-size logos in the account picker.
- Copy sign-in commands and links show clipboard success, retry feedback, and VoiceOver announcements without shifting the layout.
- Shared version source and version/build information in Preferences.
- Refreshed Codex/Claude website copy, native screenshots, and social cards.
- CI-gated source-release drafts, text-asset checksums, and an installer pinned to a reviewed 0.1.1 source checkpoint.
- Production-only website analytics wiring, privacy-signal handling, and plan-gated install-interest events; no app telemetry.

## 0.1.0 — initial source version

- Native macOS menu bar panel for Codex usage and reset windows.
- Earned reset information when provided by Codex.
- Isolated multi-account browser sign-in and Chrome profile selection.
- Compact account switching linked to expanded account management.
- Inline Preferences, interruptible panel resize, full-row selection, and quit confirmation.
- System/Light/Dark appearances and Reduce Motion support.
- Two-window brand artwork, isolated demo mode, landing page with sanitized real app captures, and local download packaging.
- Contribution docs, issue/PR templates, and macOS CI configuration.

No public release has been published yet.
