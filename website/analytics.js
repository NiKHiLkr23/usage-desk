// Website-only analytics. Never load on localhost, preview deployments, or in the native app.
(() => {
  const origin = 'https://usage-desk.nikhilkr.in';
  const optedOut = navigator.globalPrivacyControl === true ||
    [navigator.doNotTrack, window.doNotTrack].some(value => value === '1' || value === 'yes');
  if (window.location.origin !== origin || optedOut) return;

  const paths = new Set(['/', '/index.html', '/privacy.html', '/brand.html']);
  const names = new Set(['Install command copied', 'GitHub opened']);
  const placements = new Set(['hero', 'footer']);
  const safeURL = value => {
    try {
      const url = new URL(value, origin);
      return origin + (paths.has(url.pathname) ? url.pathname : '/404');
    } catch { return origin + '/404'; }
  };
  const beforeSend = event => {
    if (event.type !== 'pageview' && event.type !== 'event') return null;
    const clean = { ...event, url: safeURL(event.url) };
    if (event.type === 'event') {
      if (!names.has(event.name)) return null;
      clean.data = placements.has(event.data?.placement) ? { placement: event.data.placement } : {};
    }
    return clean;
  };

  async function start() {
    try {
      const response = await fetch('/analytics-config.json', { cache: 'no-cache' });
      if (!response.ok) return;
      const config = await response.json();
      if (config.enabled !== true) return;
      window.va = window.va || function (...args) { (window.vaq = window.vaq || []).push(args); };
      window.va('beforeSend', beforeSend);
      const script = document.createElement('script');
      script.src = '/_vercel/insights/script.js';
      script.defer = true;
      // Failed/blocked analytics must never interfere with navigation or installation.
      script.onerror = () => { window.va = () => {}; window.vaq = []; };
      document.head.appendChild(script);

      // Vercel custom events require Pro/Enterprise. Keep false until the plan is verified.
      if (config.customEvents !== true) return;
      document.addEventListener('usage-desk:install-command-copied', event => {
        const placement = event.detail?.placement;
        if (placements.has(placement)) window.va('event', { name: 'Install command copied', data: { placement } });
      });
      document.addEventListener('click', event => {
        const link = event.target?.closest?.('a[data-repository]');
        if (!link) return;
        try {
          const url = new URL(link.href);
          if (url.origin === 'https://github.com' && url.pathname.replace(/\/$/, '') === '/NiKHiLkr23/usage-desk') {
            window.va('event', { name: 'GitHub opened' });
          }
        } catch { /* Ignore unexpected link values. */ }
      });
    } catch { /* Analytics is optional; the website remains fully functional. */ }
  }
  void start();
})();
