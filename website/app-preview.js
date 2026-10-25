(() => {
  const host = document.querySelector('[data-app-preview]');
  if (!host) return;
  const sample = [
    { id: 'personal', label: 'Personal', provider: 'codex', email: 'personal@example.com', plan: 'Plus', short: 35, week: 90, reset: '3h 37m', weeklyReset: '6d 22h', credits: 1 },
    { id: 'work', label: 'Work', provider: 'codex', email: 'work@example.com', plan: 'Plus', short: 62, week: 75, reset: '1h 24m', weeklyReset: '4d 8h', credits: 0 },
    { id: 'claude', label: 'Side projects', provider: 'claude', email: 'projects@example.com', plan: 'Pro', short: 72, week: 41, reset: '2h 18m', weeklyReset: '5d 11h', credits: null },
  ];
  const state = { account: 'personal', tab: 'usage', resetTab: 'earned', page: 'main', detail: 'personal', menu: false, showQuota: true, refresh: '60', refreshing: false };
  const observedAt = Date.now();
  const dateLabel = duration => {
    let minutes = 0;
    for (const [, value, unit] of duration.matchAll(/(\d+)([dhm])/g)) minutes += Number(value) * ({ d: 1440, h: 60, m: 1 }[unit]);
    return new Date(observedAt + minutes * 60000).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
  };
  const drafts = new Map();
  const labels = new Map(sample.map(account => [account.id, account.label]));
  const get = selector => host.querySelector(selector);
  const account = () => sample.find(item => item.id === state.account);
  const name = item => labels.get(item.id);
  const escape = value => String(value).replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
  const icon = (id, extra = '') => `<svg class="preview-glyph ${extra}" aria-hidden="true" viewBox="0 0 24 24"><use href="assets/ui-icons.svg#${id}"></use></svg>`;
  const provider = item => `<span class="preview-provider ${item.provider}" role="img" aria-label="${item.provider === 'claude' ? 'Claude' : 'Codex'}"></span>`;
  const quotaClass = percent => percent <= 0 ? 'is-empty' : percent <= 20 ? 'is-low' : '';
  function meter(title, percent, reset) {
    return `<div class="preview-meter ${quotaClass(percent)}"><div class="preview-meter-top"><span>${title}</span><span>${account().provider === 'claude' ? 'Claude' : 'Codex'}</span></div><div class="preview-percent"><span>${percent}</span><span>% left</span></div><div class="preview-bars" role="img" aria-label="${percent} percent remaining">${Array.from({ length: 12 }, (_, index) => `<i${index / 12 < percent / 100 ? ' class="filled"' : ''}></i>`).join('')}</div><p class="preview-reset">Resets in ${reset}</p></div>`;
  }
  function renderUsage() {
    const item = account();
    get('[data-preview-meters]').innerHTML = meter('5-hour window', item.short, item.reset) + meter('Weekly window', item.week, item.weeklyReset);
    get('[data-earned-shortcut]').hidden = item.provider === 'claude';
    get('[data-earned-count]').textContent = `${item.credits} available`;
  }
  function renderResets() {
    const item = account();
    get('[data-reset-tabs]').hidden = item.provider === 'claude';
    const earned = item.provider !== 'claude' && state.resetTab === 'earned';
    const content = earned
      ? `<div class="preview-earned-heading"><strong>Earned resets</strong><span>${item.credits} available</span></div>${item.credits ? '<div class="preview-reset-card">' + '<strong>Full reset</strong><p>Resets your Codex usage windows.</p><p>Expires in 7 days</p><p>Available</p></div>' : '<p class="preview-note">No individual credit details returned.</p>'}<p class="preview-note">Redeem in Codex.</p>`
      : `<div class="preview-reset-card preview-schedule"><div><strong>5-hour window</strong><span>${item.provider === 'claude' ? 'Claude' : 'Codex'}</span><span>${dateLabel(item.reset)}</span></div><span>${item.reset}</span></div><div class="preview-reset-card preview-schedule"><div><strong>Weekly window</strong><span>${item.provider === 'claude' ? 'Claude' : 'Codex'}</span><span>${dateLabel(item.weeklyReset)}</span></div><span>${item.weeklyReset}</span></div><p class="preview-note">Times use your Mac’s time zone. An elapsed countdown awaits a usage update.</p>`;
    const target = get(earned ? '[data-reset-earned-panel]' : '[data-reset-schedule-panel]');
    get('[data-reset-earned-panel]').hidden = !earned;
    get('[data-reset-schedule-panel]').hidden = earned;
    target.innerHTML = content;
    get('[data-reset-tabs]').dataset.index = state.resetTab === 'earned' ? '0' : '1';
    host.querySelectorAll('[data-reset-tab]').forEach(button => {
      const selected = button.dataset.resetTab === state.resetTab;
      button.setAttribute('aria-selected', String(selected)); button.tabIndex = selected ? 0 : -1;
    });
  }
  function renderAccounts() {
    get('[data-account-rows]').innerHTML = sample.map(item => `<div class="preview-account-row${item.id === state.account ? ' selected' : ''}"><button class="preview-account-view" type="button" data-view-account="${item.id}" aria-label="View usage for ${escape(name(item))}, ${item.short} percent left"><span class="preview-row-provider">${provider(item)}</span><span class="preview-account-identity"><strong>${escape(name(item))}</strong><span>${item.email}</span></span><span class="preview-account-quota">${item.id === state.account ? icon('check') : ''}<span><strong>${item.short}% left</strong><span>Resets in ${item.reset}</span></span></span></button><button type="button" class="preview-icon-button preview-gear-button" data-manage-account="${item.id}" aria-label="Account settings for ${escape(name(item))}" title="Account settings for ${escape(name(item))}">${icon('gear', 'preview-gear')}</button></div>`).join('');
  }
  function renderMenu() {
    const menu = get('[data-account-menu]');
    menu.hidden = !state.menu;
    get('[data-account-picker]').setAttribute('aria-expanded', String(state.menu));
    menu.innerHTML = sample.map(item => `<button type="button" role="menuitemradio" tabindex="-1" aria-checked="${item.id === state.account}" data-pick-account="${item.id}">${provider(item)}<span>${escape(name(item))}</span>${item.id === state.account ? icon('check') : ''}</button>`).join('');
  }
  function renderDetails() {
    const item = sample.find(entry => entry.id === state.detail);
    get('[data-detail-identity]').innerHTML = `<div class="preview-detail-provider">${provider(item)}<strong>${item.provider === 'claude' ? 'Claude CLI connected' : 'Authenticated with OpenAI'}</strong></div><p>${item.email}</p><p>${item.plan}</p>`;
    get('[data-preview-label]').value = drafts.get(item.id) ?? name(item);
    get('[data-save-name]').textContent = 'Save'; get('[data-save-name]').disabled = get('[data-preview-label]').value.trim() === name(item);
    get('[data-name-feedback]').textContent = '';
  }
  function render() {
    const item = account();
    get('[data-preview-title]').textContent = state.page === 'preferences' ? 'Preferences' : state.page === 'details' ? 'Accounts' : 'usage desk';
    get('[data-preview-back]').hidden = state.page === 'main';
    get('[data-preview-refresh]').hidden = state.page !== 'main';
    get('[data-preview-preferences]').disabled = state.page === 'preferences';
    get('[data-preview-main]').hidden = state.page !== 'main';
    get('[data-preview-preferences-page]').hidden = state.page !== 'preferences';
    get('[data-preview-details-page]').hidden = state.page !== 'details';
    get('[data-preview-footer]').hidden = state.page !== 'main';
    get('[data-selected-provider]').innerHTML = provider(item);
    get('[data-selected-name]').textContent = name(item);
    get('[data-selected-email]').textContent = item.email;
    get('[data-selected-plan]').textContent = item.plan;
    const resetLabel = get('[data-resets-label]');
    resetLabel.textContent = item.provider === 'claude' ? 'Resets' : `Resets · ${item.credits}`;
    const tabs = get('[data-preview-tabs]');
    tabs.dataset.index = String(['usage', 'resets', 'accounts'].indexOf(state.tab));
    host.querySelectorAll('[data-preview-tab]').forEach(button => {
      const selected = button.dataset.previewTab === state.tab;
      button.setAttribute('aria-selected', String(selected)); button.tabIndex = selected ? 0 : -1;
      document.getElementById(button.getAttribute('aria-controls')).hidden = !selected;
    });
    get('[data-menu-title]').textContent = state.showQuota ? `${item.short}%` : 'usage desk';
    renderUsage(); renderResets(); renderAccounts(); renderMenu();
    if (state.page === 'details') renderDetails();
    window.UsageDeskTheme?.refreshControls();
  }
  function selectTab(tab, focus = false) {
    state.tab = tab; state.page = 'main'; state.menu = false; render();
    if (focus) get(`[data-preview-tab="${tab}"]`).focus({ preventScroll: true });
  }
  function settings(id) { state.detail = id; state.page = 'details'; state.menu = false; render(); get('[data-preview-label]').focus({ preventScroll: true }); }
  function refresh() {
    if (state.refreshing) return;
    state.refreshing = true;
    const button = get('[data-preview-refresh]'); button.disabled = true; button.classList.add('refreshing');
    get('[data-preview-status]').textContent = 'Updating…';
    setTimeout(() => {
      state.refreshing = false; button.disabled = false; button.classList.remove('refreshing');
      get('[data-preview-status]').textContent = 'Live · Just updated';
    }, 450);
  }
  host.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button || button.disabled) return;
    if (button.hasAttribute('data-preview-tab')) selectTab(button.dataset.previewTab);
    else if (button.hasAttribute('data-reset-tab')) { state.resetTab = button.dataset.resetTab; renderResets(); }
    else if (button.hasAttribute('data-account-picker')) { state.menu = !state.menu; renderMenu(); }
    else if (button.hasAttribute('data-pick-account')) { state.account = button.dataset.pickAccount; state.menu = false; render(); get('[data-account-picker]').focus({ preventScroll: true }); }
    else if (button.hasAttribute('data-view-account')) { state.account = button.dataset.viewAccount; selectTab('usage', true); }
    else if (button.hasAttribute('data-manage-account')) settings(button.dataset.manageAccount);
    else if (button.hasAttribute('data-manage-selected')) settings(state.account);
    else if (button.hasAttribute('data-detail-usage')) { state.account = state.detail; selectTab('usage', true); }
    else if (button.hasAttribute('data-preview-preferences')) { state.menu = false; state.returnPage = state.page; state.page = 'preferences'; render(); get('[data-preview-back]').focus({ preventScroll: true }); }
    else if (button.hasAttribute('data-preview-back')) { state.page = state.page === 'preferences' ? (state.returnPage || 'main') : 'main'; render(); get(state.page === 'details' ? '[data-preview-label]' : `[data-preview-tab="${state.tab}"]`).focus({ preventScroll: true }); }
    else if (button.hasAttribute('data-preview-refresh')) refresh();
    else if (button.hasAttribute('data-earned-shortcut')) { state.resetTab = 'earned'; selectTab('resets'); }
    else if (button.hasAttribute('data-preview-entry')) {
      const panel = get('[data-preview-panel]'); panel.hidden = !panel.hidden; button.setAttribute('aria-expanded', String(!panel.hidden));
    }
  });
  host.addEventListener('keydown', event => {
    const tab = event.target.closest('[data-preview-tab], [data-reset-tab]');
    if (tab) {
      const group = tab.parentElement;
      const items = [...group.querySelectorAll('[role="tab"]')];
      const index = items.indexOf(tab);
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % items.length;
      if (event.key === 'ArrowLeft') next = (index + items.length - 1) % items.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = items.length - 1;
      if (next !== undefined) { event.preventDefault(); items[next].click(); items[next].focus({ preventScroll: true }); }
    }
    if (state.menu && event.key === 'Tab') {
      state.menu = false; renderMenu(); get('[data-account-picker]').focus({ preventScroll: true });
    }
    if (state.menu && ['ArrowDown', 'ArrowUp', 'Home', 'End', 'Escape'].includes(event.key)) {
      event.preventDefault();
      if (event.key === 'Escape') { state.menu = false; renderMenu(); get('[data-account-picker]').focus(); return; }
      const items = [...get('[data-account-menu]').querySelectorAll('button')];
      const index = items.indexOf(document.activeElement);
      const next = event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : index < 0 ? (event.key === 'ArrowUp' ? items.length - 1 : 0) : (index + (event.key === 'ArrowUp' ? items.length - 1 : 1)) % items.length;
      items[next].focus();
    }
  });
  document.addEventListener('click', event => { if (state.menu && !event.target.closest('[data-account-picker-wrap]')) { state.menu = false; renderMenu(); } });
  get('[data-preview-label]').addEventListener('input', event => {
    drafts.set(state.detail, event.target.value);
    get('[data-save-name]').textContent = 'Save'; get('[data-save-name]').disabled = event.target.value.trim() === labels.get(state.detail);
    get('[data-name-feedback]').textContent = '';
  });
  get('[data-name-form]').addEventListener('submit', event => {
    event.preventDefault();
    const label = get('[data-preview-label]').value.trim();
    if (!label || label.length > 80 || /[\u0000-\u001f\u007f]/.test(label)) { get('[data-name-feedback]').textContent = 'Enter a name of up to 80 characters.'; return; }
    labels.set(state.detail, label); drafts.delete(state.detail); render(); get('[data-save-name]').textContent = 'Saved';
    get('[data-name-feedback]').textContent = 'Display name saved.';
    get('[data-preview-label]').focus({ preventScroll: true });
  });
  get('[data-menu-quota]').addEventListener('change', event => { state.showQuota = event.target.checked; get('[data-menu-title]').textContent = state.showQuota ? `${account().short}%` : 'usage desk'; });
  get('[data-preview-interval]').addEventListener('change', event => { state.refresh = event.target.value; });
  render();
})();
