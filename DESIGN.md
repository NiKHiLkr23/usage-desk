# Usage Desk native interface

Keep the existing compact monochrome menu-bar panel, System appearance default, full-row
account hit targets, and interruptible size transitions with Reduce Motion support.

## Providers

Add account begins with Codex / Claude choices, each with a provider icon; Claude uses #D97757 orange.
Keep one account list and the existing Usage / Resets / Accounts tabs. Provider identity
travels with each stored profile; pre-provider saved profiles decode as Codex.
Use provider marks in the selected account header, quick account list, account menu, and
management sidebar. Provider text/tooltips/accessibility labels identify the icons.

Codex keeps the existing isolated browser sign-in flow. Claude connects an existing CLI
configuration directory, defaulting to ~/.claude. This matches the CLI identity used by T3
without replacing it. Users can choose a different configuration directory for another
account. A missing sign-in has a copyable, shell-quoted CLI login command and Refresh;
Usage Desk does not collect credentials or change Claude settings.

Claude usage is a point-in-time CLI control read, with its own five-hour/weekly windows.
Unknown windows stay unknown. Only report successful observation timestamps. Error recovery
preserves clearly labelled last-known usage. Claude resets show the reported schedule;
get_usage has no earned reset-credit feed, so hide the earned-credit controls for Claude.

Provider icons: Simple Icons v14.15.0 (CC0), notices in the bundled Resources/NOTICE.txt.
The website now uses an explicitly approved interactive native-style preview with sample accounts.
Keep authentic repository captures separate from the website preview.

## Action feedback

Copy buttons show a checkmark and “Copied” only after the clipboard accepts the value.
Keep their width stable and restore the normal label after two seconds; repeated copying
restarts that interval. A failed copy stays visible with a retry hint. Announce the result
to VoiceOver without retaining or announcing the command or sign-in URL. Feedback tasks
cancel when the control leaves the view. Use the same behavior for both providers.

Native menu items use a `Label` with an NSImage explicitly sized to 14 points. SwiftUI
frame/resizable modifiers do not define an NSMenu image’s size, and its bridge can drop
template tinting. Render menu icons with the current light/dark foreground; keep regular
provider icons templated. Retain the original pixel representation for crisp Retina rendering.

## Appearance motion

A circular reveal grows from the theme control over 480 ms. The overlay belongs to an AppKit
container above the SwiftUI hosting view, so appearance updates cannot remove its backing layer. Apply the new appearance immediately;
mask an in-memory picture of this app’s own content until the reveal completes. The overlay never
intercepts input and is discarded on replacement, navigation, dismissal or Reduce Motion. Never
persist or transmit the picture. Effective-theme changes only; System remains the default.

Apply explicit Light/Dark appearance to the owning popover window as well as the app.
Pass the chosen color scheme into SwiftUI so semantic colors repaint even when the menu-bar
anchor has its own appearance. System clears both overrides and follows inherited appearance.
