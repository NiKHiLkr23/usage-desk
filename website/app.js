const root = document.documentElement;
const themeButton = document.querySelector('.theme-toggle');
let choice = 'system';
try { const saved=localStorage.getItem('usageDeskSiteTheme'); if(['light','dark','system'].includes(saved)) choice=saved; } catch {}
function applyTheme() {
  if(choice==='system') delete root.dataset.theme; else root.dataset.theme=choice;
  if(!themeButton) return;
  const next={system:'light',light:'dark',dark:'system'}[choice];
  themeButton.dataset.choice=choice;
  themeButton.setAttribute('aria-label',`Theme: ${choice[0].toUpperCase()+choice.slice(1)}. Switch to ${next} mode.`);
  themeButton.title=`${choice[0].toUpperCase()+choice.slice(1)} theme · Click for ${next}`;
}
applyTheme();
themeButton?.addEventListener('click',()=>{choice={system:'light',light:'dark',dark:'system'}[choice];try{localStorage.setItem('usageDeskSiteTheme',choice)}catch{}applyTheme()});

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

const tablist = document.querySelector('[data-showcase-tabs]');
if (tablist) {
  const tabs = [...tablist.querySelectorAll('[role=tab]')];
  const panels = tabs.map(tab => document.getElementById(tab.getAttribute('aria-controls')));
  if (panels.every(Boolean)) {
    tablist.hidden = false;
    function selectTab(index, focus = false) {
      tabs.forEach((tab, current) => {
        const selected = current === index;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        panels[current].hidden = !selected;
      });
      if (focus) tabs[index].focus();
    }
    tabs.forEach((tab, index) => {
      tab.addEventListener('click', () => selectTab(index));
      tab.addEventListener('keydown', event => {
        let next;
        if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
        if (event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
        if (event.key === 'Home') next = 0;
        if (event.key === 'End') next = tabs.length - 1;
        if (next === undefined) return;
        event.preventDefault();
        selectTab(next, true);
      });
    });
  }
}
