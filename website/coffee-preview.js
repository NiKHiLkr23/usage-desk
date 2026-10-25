// The browser previews the native glyph only. No wake lock, power API or persistence.
(() => {
  const button = document.querySelector('[data-preview-coffee]');
  if (!button) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const liquid = button.querySelector('[data-coffee-liquid]');
  const outlines = button.querySelectorAll('[data-coffee-outline]');
  const steam = button.querySelector('[data-coffee-steam]');
  const steamPaths = button.querySelectorAll('[data-coffee-steam-path]');
  let active = false, hovered = false, visible = false, frame = 0, started = 0;
  const canMove = () => visible && !document.hidden && !reduced.matches;

  function draw(elapsed = 0) {
    const moving = canMove();
    const p = moving && hovered ? Math.min(1, elapsed / 850) : 0;
    const eased = 1 - (1 - p) ** 3;
    const angle = moving && active ? 2 * Math.PI * elapsed / 2400 : 0;
    const wave = active ? 1.3 * Math.sin(angle) : 1.5 * Math.sin(p * Math.PI * 3) * Math.sin(p * Math.PI);
    const fill = active ? .66 : .63 * eased;
    const y = 15.7 - 8.3 * fill;
    liquid.setAttribute('d', `M2.5 ${y}C6 ${y + wave * 1.3} 10 ${y - wave * 1.3} 15 ${y}V17H2.5Z`);
    liquid.setAttribute('opacity', fill > 0 ? '1' : '0');
    const reveal = active || p === 0 ? 1 : eased;
    outlines.forEach(path => path.setAttribute('stroke-dasharray', `${reveal} 1`));
    const sway = active ? .45 * Math.sin(angle) : 0;
    const lift = active ? .45 * (1 - Math.cos(angle)) : 0;
    steam.setAttribute('opacity', active ? (moving ? .78 + .12 * Math.cos(angle) : 1) : eased);
    steamPaths.forEach(path => {
      const x = Number(path.dataset.coffeeSteamPath);
      path.setAttribute('d', `M${x} ${5.6 - lift * .3}C${x - 1.8 + sway} ${4.1 - lift} ${x + 1.8 + sway} ${3.4 - lift} ${x + sway} ${1.7 - lift}`);
      path.setAttribute('stroke-dasharray', `${active ? 1 : eased} 1`);
    });
  }
  function tick(now) {
    frame = 0;
    draw(now - started);
    if (canMove() && (active || (hovered && now - started < 850))) frame = requestAnimationFrame(tick);
  }
  function restart() {
    cancelAnimationFrame(frame); frame = 0; started = performance.now(); draw();
    if (canMove() && (active || hovered)) frame = requestAnimationFrame(tick);
  }
  button.addEventListener('click', () => {
    active = !active;
    if (!active) hovered = false;
    button.setAttribute('aria-pressed', String(active));
    button.title = `Keep awake: ${active ? 'On' : 'Off'}. Website animation only.`;
    restart();
  });
  button.addEventListener('pointerenter', () => { hovered = true; if (!active) restart(); });
  button.addEventListener('pointerleave', () => { hovered = false; if (!active) restart(); });
  reduced.addEventListener('change', restart);
  document.addEventListener('visibilitychange', restart);
  // Hidden panels and offscreen previews must not keep scheduling animation frames.
  const observer = new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting; restart();
  });
  observer.observe(button);
  draw();
})();
