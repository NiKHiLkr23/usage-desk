(() => {
  const root = document.documentElement;
  const system = window.matchMedia('(prefers-color-scheme: dark)');
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  const cycle = { system: 'light', light: 'dark', dark: 'system' };
  let choice = 'system';
  let transition;
  let animation;
  let revision = 0;
  try { const saved = localStorage.getItem('usageDeskSiteTheme'); if (Object.hasOwn(cycle, saved)) choice = saved; } catch {}
  const resolved = value => value === 'system' ? (system.matches ? 'dark' : 'light') : value;
  function refreshControls() {
    document.querySelectorAll('[data-theme-control], .theme-toggle').forEach(button => {
      button.dataset.choice = choice;
      const title = choice[0].toUpperCase() + choice.slice(1);
      button.setAttribute('aria-label', `Theme: ${title}. Switch to ${cycle[choice]} mode.`);
      button.title = `${title} theme · Click for ${cycle[choice]}`;
    });
    document.querySelectorAll('[data-current-theme]').forEach(label => { label.textContent = choice[0].toUpperCase() + choice.slice(1); });
  }
  function apply() {
    if (choice === 'system') delete root.dataset.theme; else root.dataset.theme = choice;
    root.dataset.resolvedTheme = resolved(choice);
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', resolved(choice) === 'dark' ? '#141414' : '#ffffff');
    refreshControls();
  }
  function set(next, origin) {
    if (!Object.hasOwn(cycle, next)) return;
    const previous = resolved(choice);
    choice = next;
    try { localStorage.setItem('usageDeskSiteTheme', choice); } catch {}
    revision += 1;
    const current = revision;
    animation?.cancel();
    transition?.skipTransition();
    if (reduced.matches || !document.startViewTransition || previous === resolved(choice)) { apply(); return; }
    const bounds = origin?.getBoundingClientRect();
    const x = bounds ? bounds.left + bounds.width / 2 : innerWidth / 2;
    const y = bounds ? bounds.top + bounds.height / 2 : innerHeight / 2;
    const radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
    try {
      const active = document.startViewTransition(apply);
      transition = active;
      active.ready.then(() => {
        if (current !== revision || reduced.matches) { active.skipTransition(); return; }
        animation = root.animate({ clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${radius}px at ${x}px ${y}px)`] },
          { duration: 480, easing: 'cubic-bezier(.4, 0, .2, 1)', pseudoElement: '::view-transition-new(root)' });
      }).catch(() => {});
      active.finished.catch(() => {}).finally(() => { if (transition === active) transition = undefined; });
      active.updateCallbackDone.catch(apply);
    } catch { apply(); }
  }
  window.UsageDeskTheme = { get choice() { return choice; }, get resolved() { return resolved(choice); },
    set, cycle: origin => set(cycle[choice], origin), refreshControls };
  apply();
  document.addEventListener('DOMContentLoaded', refreshControls, { once: true });
  document.addEventListener('click', event => {
    const button = event.target.closest('button[data-theme-control], button.theme-toggle');
    if (button) window.UsageDeskTheme.cycle(button);
  });
  system.addEventListener('change', apply);
  reduced.addEventListener('change', () => { if (reduced.matches) { animation?.cancel(); transition?.skipTransition(); } });
})();
