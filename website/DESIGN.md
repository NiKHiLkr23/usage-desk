# Usage Desk website design

## Intent and hierarchy

A small native macOS utility for people tracking Codex quotas across accounts. Lead with
what it does, the source-install command, and the real app. GitHub stars are a secondary
community action. Keep requirements beside the command: local compilation, macOS 14+,
Swift 6+, Xcode Command Line Tools, and an installed/signed-in Codex CLI for app use.

## Existing design system

`style.css` contains the executable color, typography, spacing, and motion rules.
Use black and white with a system-first appearance toggle. Green is limited to the logo,
quota/status indicators inside native captures, focus outlines, and successful copy feedback.
Retain Helvetica Neue/system fallbacks and ample spacing. Buttons and preview tabs are
fully rounded; command fields and the app frame use softer rectangular corners.

## Components and states

- Install command: selectable monospace code, separate shell prompt, persistent copy control.
  Copy exactly the command, excluding the prompt. Keep the button width stable as its label
  changes to Copied. Clipboard denial selects the command and gives visible recovery guidance.
- GitHub star: ordinary repository link with an outlined star. No automatic starring, fake
  counts, runtime third-party requests, or new analytics.
- Product tabs: Usage, Accounts, Resets. Use actual `DeskRootView`/`DashboardView` renders
  with `AccountStore(demo: true)`; omit the presentation-only Demo badge from captures
  and disclose sample account data in the caption. Keep all demo safety guards active.
  No HTML product reconstructions or generated app imagery. Use identical image dimensions
  to prevent layout shifts. Usage remains visible without JavaScript; controls are enhanced only
  when their backing behavior exists.
- Keep the full install instructions near the bottom, with the same copy behavior.
- Footer: a spacious brand/headline block on the left, two link columns on the right,
  and a divider above the copyright and right-aligned maker/license credit. A faint decorative
  wordmark sits at the bottom. Adapt Hunchlane’s layout using Usage Desk’s existing palette
  and typography; omit the dotted pattern and affiliation disclaimer.

## Accessibility and motion

Use semantic buttons, tablist/tab/tabpanel roles, roving tab focus, ArrowLeft/ArrowRight,
Home/End, visible focus, and announced clipboard feedback. The command can scroll within
its field on narrow screens without overflowing the page. Existing reduced-motion rules
remove transitions. Tabs switch immediately; no autoplay or decorative entrance sequences.
The native screenshots remain in light appearance across website themes, with a visible frame.

## Verification

`node scripts/check-website.mjs` checks structure, SEO, public files, and isolated installer
scenarios. Inspect the local preview at desktop and narrow widths, with light/dark themes,
keyboard tabs, repeated copying, and clipboard fallback. Never run the pasted installer as
part of a website copy-button test. Native app logic is outside this website polish.

## Decisions

2026-10-19: Accepted the install-command and GitHub-star hierarchy inspired by px0.ai,
adapted to Usage Desk's existing neutral design. Added tabbed native captures with sample
accounts. No upstream CSS, JavaScript, or artwork was copied.

2026-10-19: Adapted the Hunchlane footer composition from the maintainer’s local reference
repository. Reimplemented it in static HTML/CSS with Usage Desk assets and tokens.
