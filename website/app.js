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
