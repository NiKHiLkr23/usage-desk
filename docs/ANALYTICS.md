# Website measurement

Website analytics is separate from the native app. Neither the app nor source installer reports
account information, successful installations, or active users.

## What is wired

`website/analytics.js` loads Vercel's same-origin `/_vercel/insights/script.js` only on
`https://usage-desk.nikhilkr.in`. It never loads on localhost, IP addresses, or Vercel preview URLs.
Browser Do Not Track or Global Privacy Control disables it. It uses no analytics cookie, does not
add a persistent user ID, and strips query strings/fragments from page URLs before sending. Public
paths are allowlisted; unknown paths become `/404`. There is no free-text event payload.
Blocking analytics never disables the theme, copy buttons, product tabs, or links.

`analytics-config.json` is a deployment-side kill switch. `enabled: false` prevents SDK loading.
The current `customEvents: false` enables only page-view measurement after hosting activation.
Run `npm run analytics:check` for isolated, network-free privacy and payload checks.
The code supports two optional events:

| Event | When | Payload |
| --- | --- | --- |
| Install command copied | Clipboard write succeeds | Fixed placement: `hero` or `footer` |
| GitHub opened | A repository link is clicked | No custom payload |

Failed/manual copy fallback is not counted as a successful copy. Never send the command itself,
clipboard content, page queries, emails, local paths, account IDs, credentials, or quota values.
Vercel's provider processes ordinary analytics request/device/referral information under its policy.

## Activate after release review

1. Open the Usage Desk project in Vercel, then Web Analytics. Verify the current plan and included
   allowance before enabling it; do not upgrade a plan as part of setup without a separate decision.
2. Enable Web Analytics and deploy the reviewed branch to production. Adding source code alone
   does not activate the hosting routes. No token or analytics secret belongs in this repository.
3. Check the same-origin insights script returns JavaScript, inspect a real page-view request for
   the URL filter, then confirm the project dashboard receives data. Test with privacy signals off;
   verify tracking stays off when Do Not Track/GPC is enabled. Do not inject artificial production events.
4. Vercel custom events require Pro or Enterprise. Keep `customEvents: false` on Hobby. If an existing
   eligible plan is confirmed, set it to true, review the change, deploy, and verify a real copy and
   GitHub click. No paid plan change is performed automatically.
5. Keep the public Privacy page accurate. To stop collection, set `enabled: false` and redeploy;
   disabling it in the dashboard is also available. Local tests use a fake collector with no network.

## Reading the numbers

Visitors are estimates, not a stable count of people. Command copies and GitHub clicks show intent;
they are not confirmed installs. Release-asset downloads and repository clones are also proxies.
Successful installs or weekly active users cannot be recovered retrospectively from this setup.
Measuring those would require a separately designed, disclosed, opt-in app/installer mechanism.

References: [setup](https://vercel.com/docs/analytics/quickstart),
[custom events and plan availability](https://vercel.com/docs/analytics/custom-events),
[privacy](https://vercel.com/docs/analytics/privacy-policy),
[pricing](https://vercel.com/docs/analytics/limits-and-pricing).
