# Usage Desk website design

## Intent and hierarchy

A small native macOS utility for people tracking Codex and Claude quotas across accounts. Lead with
what it does, the source-install command, and an interactive app preview. GitHub stars are a secondary
community action. Keep the hero focused on the product, install command and actions.
Put build requirements and script inspection in the lower installation section.

## Existing design system

`style.css` contains the executable color, typography, spacing, and motion rules.
Use black and white with a system-first appearance toggle. Green is limited to the logo,
quota/status indicators inside the preview, focus outlines, and successful copy feedback.
Claude uses its provider orange (#D97757). Retain Helvetica Neue/system fallbacks and ample spacing. Buttons and preview tabs are
fully rounded; command fields and the app frame use softer rectangular corners.

## Components and states

- Install command: selectable monospace code, separate shell prompt, persistent copy control.
  Copy exactly the command, excluding the prompt. Keep the button width stable as its label
  changes to Copied. Clipboard denial selects the command and gives visible recovery guidance.
- GitHub star: ordinary repository link with an outlined star. No automatic starring, fake
  counts, or automatic GitHub API requests. Production-only, cookie-free Vercel analytics is a
  separate approved measurement layer; no app/account telemetry.
- Interactive product preview: native-style Usage, Resets, Accounts, account details and Preferences.
  HTML/CSS uses the native app's layout, colors and type scale, with three fixed example.com accounts.
  A single selected-tab pill slides between buttons; content switches immediately.
  Provider switching changes quotas/reset availability. Gears open the chosen account without changing
  the viewed account. Editing display names is memory-only and gives Saved feedback.
  The menu-bar entry toggles the panel. No Add account, sign-in, reconnect, removal, Quit, CLI path,
  launch-at-login, or real provider calls are exposed. Preferences intentionally shows only previewable controls.
  Keep the hero free of preview/sample captions. Explain sample data on the Privacy page.
  The interface is a reconstruction, not a native screenshot.
  Keep Usage readable without JavaScript. Fixed panel height prevents layout shifts on page navigation.
- Keep the full install instructions near the bottom, with the same copy behavior.
- Footer: a spacious brand/headline block on the left, two link columns on the right,
  and a divider above the copyright and right-aligned maker/license credit. A faint decorative
  wordmark sits at the bottom. Adapt Hunchlane’s layout using Usage Desk’s existing palette
  and typography; omit the dotted pattern and affiliation disclaimer.

## Accessibility and motion

Use semantic buttons, tablist/tab/tabpanel roles, roving tab focus, ArrowLeft/ArrowRight,
Home/End, visible focus, and announced clipboard feedback. The command can scroll within
its field on narrow screens without overflowing the page. Reduce Motion removes transitions. The gear rotates forward once through 90 degrees on hover;
Preferences knobs slide once and hold. Both reset instantly on exit. Tabs animate over 280 ms.
Theme controls share one System → Light → Dark preference. A 480 ms circular reveal grows from
whichever theme button was pressed across the whole viewport, using the View Transition API.
Unsupported browsers, unchanged effective themes, or Reduce Motion switch instantly. Rapid changes
cancel old effects. No autoplay, simulated quota changes, or decorative entrance sequences.

## Verification

`node scripts/check-website.mjs` checks structure, SEO, public files, and isolated installer
scenarios. Inspect the local preview at desktop and narrow widths, with light/dark themes,
keyboard tabs, repeated copying, and clipboard fallback. Never run the pasted installer as
part of a website copy-button test. The native appearance reveal is a separate AppKit layer; no account logic is shared with the preview.

## Decisions

2026-10-19: Accepted the install-command and GitHub-star hierarchy inspired by px0.ai,
adapted to Usage Desk's existing neutral design. Added tabbed native captures with sample
accounts. No upstream CSS, JavaScript, or artwork was copied.

2026-10-19: Adapted the Hunchlane footer composition from the maintainer’s local reference
repository. Reimplemented it in static HTML/CSS with Usage Desk assets and tokens.

2026-10-19: Source installer uses a compact two-windows text mark, green success checks,
real build phases, and a restrained terminal spinner. Keep build noise in a private log with
visible failure recovery. Offer app launch after installation; never require clickable links
or an extra GUI dependency. Website images explicitly disable dragging, including logos
and native product captures; normal links and brand downloads remain available.

2026-10-25: The maintainer explicitly replaced website screenshots with an interactive native-style
preview. Product PNGs were removed from the website; real repository screenshots remain available.
Provider marks reuse the app's attributed Simple Icons assets. New action glyphs are original vectors.
