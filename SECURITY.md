# Security policy

Usage Desk handles local account connections. Do not publish credentials or raw authentication data.

## Reporting a vulnerability

Use the public repository's **Security → Report a vulnerability**
(private vulnerability reporting must be enabled by the maintainer). If that option is unavailable,
contact the maintainer through [nikhilkr.in](https://nikhilkr.in) and say that you need a private
security-reporting channel. Do not put vulnerability details in a public issue or contact form initially.

Include the app/CLI/macOS versions, a description, potential impact, and reproduction steps using
synthetic accounts. Share minimal sanitized evidence. Never send real access/refresh tokens,
`auth.json`, your Codex home, Chrome cookies, or raw sign-in URLs.

This is a community-maintained prerelease project. No response-time guarantee or paid bounty is offered.
Security fixes target the current supported release; older prereleases may require an update.

## Boundaries

- Additional Codex accounts have separate local homes; Usage Desk restricts permissions on its account directories and metadata. Claude connections reference an existing CLI configuration directory and retain its sign-in.
- The Codex bridge permits account reads, rate-limit reads, and explicit login start/cancel calls. Claude probes send only initialize/get_usage and reject tool requests.
- Login URLs are validated and attempt IDs are correlated; raw backend errors are not displayed.
- No browser cookie/password extraction and no model-turn or reset-redemption endpoint is exposed.
- The app is not a security boundary against software running as the same macOS user.

See [Privacy](docs/PRIVACY.md) for storage and network behavior.
