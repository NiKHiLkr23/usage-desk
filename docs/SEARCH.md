# Search visibility

Production: https://usage-desk.nikhilkr.in/

The website is static HTML. Its product description, features, setup instructions, FAQ,
and privacy information are available without JavaScript. `robots.txt` allows crawling;
no bot-specific rules are needed to allow search or answer-engine crawlers.

## Implemented

- Each indexable page has a self-referencing canonical URL on the custom domain.
- `sitemap.xml` lists the homepage, privacy page, and brand page; `robots.txt` links to it.
- Titles, descriptions, Open Graph cards, and X/Twitter cards describe each page.
- The production `usage-desk.vercel.app` hostname permanently redirects to the matching
  custom-domain path. Vercel retains query parameters; preview hostnames are not matched.
- `/index.html` redirects to `/` so internal home links and indexing use one URL.
- Homepage JSON-LD identifies the website, webpage, native SoftwareApplication, and
  source repository. It describes free, source-only distribution and the real requirements.
- The visible FAQ answers installation, requirements, coverage, multiple accounts, Codex
  login behavior, earned-reset redemption, and cost. All answers are in the HTML.
- There are no invented reviews, ratings, installer URLs, or claims to show every ChatGPT limit.
- The 404 page is `noindex` and should return HTTP 404.
- The inline JSON-LD has an exact SHA-256 allowance in the Content Security Policy.
  When editing it, update that hash in `website/vercel.json`. The preview reads the same
  headers directly from that file; it also serves the real 404 page with status 404.

Run `node scripts/check-website.mjs` before publishing. It checks crawler discovery,
canonical URLs, share cards, structured data, CSP hashes, redirect scope, and public files.

## After deployment

1. Verify `nikhilkr.in` as a Domain property in Google Search Console, or add a URL-prefix
   property for `https://usage-desk.nikhilkr.in/`. An existing verified domain property covers
   this subdomain. Add only the actual verification value supplied by Google if needed.
2. Submit `https://usage-desk.nikhilkr.in/sitemap.xml`. Inspect the homepage and request
   indexing. Check Google's selected canonical after recrawling. If the old Vercel address
   was indexed, use Google's site-move guidance for the verified old and new properties.
3. Verify the site in Bing Webmaster Tools (or import a verified Search Console property),
   submit the same sitemap, and monitor indexing/crawl issues.
4. Check the homepage, privacy and brand pages return 200; unknown paths return 404;
   old production paths return a 308 redirect preserving path and query string.
5. Validate JSON-LD with Schema.org's validator and inspect it with Google's Rich Results
   Test. The app does not currently qualify for Google's Software App rich result because
   there are no real published ratings/reviews. Do not fabricate them to pass the test.
6. Inspect mobile page experience and social-card previews. Check Vercel Firewall and
   deployment protection if real crawlers encounter a challenge or 403 response.

Search Console and Bing verification are account-side steps, not accomplished by this
repository. Sitemap publication is not sitemap submission, and crawlability does not
confirm indexing. Rankings, AI citations, and enhanced search presentation are not guaranteed.

## Answer-engine optimization (AEO)

Keep facts useful to users: what the app does, what Codex exposes, macOS and build
requirements, installation status, pricing/license, account selection behavior, and privacy.
Update the visible content and structured data together when these change.

Google uses the same Search foundations for its AI features. It does not use `llms.txt`
as a ranking signal or require AI-specific markup. This small landing page does not need
an extra copy of its content for bots. Keep the real FAQ concise; do not add hidden answers,
keyword-stuffed pages, fake reviews, or prompt instructions intended to manipulate AI output.
An external agent-readiness score is diagnostic and does not establish search visibility.

## References

- [Google's generative AI search guidance](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
- [Moving URLs and domains](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes)
- [SoftwareApplication structured data](https://developers.google.com/search/docs/appearance/structured-data/software-app)
- [Vercel canonical production domain redirects](https://vercel.com/docs/routing/redirects#choose-a-canonical-production-domain)
- [Bing URL and sitemap submission](https://www.bing.com/webmasters/help/URL-Submission-62f2860b)

## Local verification scope

The repository checks validate source files and configuration, and local HTTP checks
validate served pages and crawler files. A plain Node preview does not execute Vercel's
hostname-based redirect rules. After publication, verify the redirects against both real
domains before treating the domain migration as complete. Search Console verification,
sitemap submission, and a fresh public audit also remain post-deployment work.
