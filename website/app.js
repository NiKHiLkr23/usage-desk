// The visible command remains selectable if clipboard access is unavailable.
for (const block of document.querySelectorAll('[data-install-block]')) {
  const button = block.querySelector('[data-copy-command]');
  const code = block.querySelector('code');
  const label = button?.querySelector('[data-copy-label]');
  const feedback = block.querySelector('[data-copy-feedback]');
  if (!button || !code || !feedback || !label) continue;
  button.hidden = false;
  let resetTimer;
  let copying = false;
  button.addEventListener('click', async () => {
    if (copying) return;
    copying = true;
    clearTimeout(resetTimer);
    delete button.dataset.copied;
    label.textContent = 'Copy';
    feedback.textContent = '';
    feedback.classList.add('visually-hidden');
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(code.textContent.trim());
      const placement = { 'install-command-hero': 'hero', 'install-command-footer': 'footer' }[code.id];
      if (placement) document.dispatchEvent(new CustomEvent('usage-desk:install-command-copied', { detail: { placement } }));
      button.dataset.copied = '';
      label.textContent = 'Copied';
      feedback.textContent = 'Install command copied.';
      resetTimer = setTimeout(() => {
        delete button.dataset.copied;
        label.textContent = 'Copy';
      }, 1800);
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(code);
      selection?.removeAllRanges();
      selection?.addRange(range);
      feedback.textContent = 'Copy unavailable. The command is selected; copy it manually.';
      feedback.classList.remove('visually-hidden');
    } finally {
      copying = false;
    }
  });
}
