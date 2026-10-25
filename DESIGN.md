# Usage Desk native interface

Keep the existing compact monochrome menu-bar panel, System appearance default, full-row
account hit targets, and interruptible size transitions with Reduce Motion support.

## Providers

Add account begins with Codex / Claude choices, each with a monochrome provider icon.
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
Keep the website's existing screenshot assets until new product imagery is reviewed.
