/**
 * Converto Navigation Bar
 * Fügt einheitliche Navigation zu allen Admin-Seiten hinzu
 * Einfach <script src="nav.js"></script> in jede Seite einfügen
 */
(function() {

  var BASE = 'https://officepuertoplata-coder.github.io/sosuapesce';

  function getSlug() {
    return new URLSearchParams(window.location.search).get('m') || 'sosuapesce';
  }

  function getCurrentPage() {
    var path = window.location.pathname;
    if (path.includes('comm.html'))       return 'comm';
    if (path.includes('admin.html'))      return 'admin';
    if (path.includes('agentes.html'))    return 'agentes';
    if (path.includes('superadmin.html')) return 'superadmin';
    if (path.includes('dashboard.html'))  return 'dashboard';
    if (path.includes('hub.html'))        return 'hub';
    return '';
  }

  function buildNav() {
    var slug = getSlug();
    var current = getCurrentPage();

    var pages = [
      { id: 'hub',        label: '🏠 Hub',             url: BASE + '/hub.html',                   always: true },
      { id: 'comm',       label: '💬 Kommunikation',   url: BASE + '/comm.html?m=' + slug,        always: true },
      { id: 'agentes',    label: '👥 Agenten',         url: BASE + '/agentes.html?m=' + slug,     always: true },
      { id: 'admin',      label: '⚙️ Admin',            url: BASE + '/admin.html?m=' + slug,       always: true },
      { id: 'superadmin', label: '👑 Superadmin',      url: BASE + '/superadmin.html',            admin: true  },
    ];

    var auth = null;
    try { auth = JSON.parse(localStorage.getItem('converto_auth_v2') || 'null'); } catch(e) {}
    var isSuperadmin = auth && auth.role === 'superadmin';

    var css = `
      #converto-nav-bar {
        position: fixed;
        top: 0; left: 0; right: 0;
        height: 48px;
        background: #0d2818;
        border-bottom: 1px solid rgba(64,145,108,0.25);
        display: flex;
        align-items: center;
        padding: 0 16px;
        gap: 4px;
        z-index: 9999;
        font-family: 'DM Sans', 'Segoe UI', sans-serif;
        box-shadow: 0 2px 12px rgba(0,0,0,0.3);
      }
      #converto-nav-bar .cnav-logo {
        display: flex;
        align-items: center;
        gap: 7px;
        margin-right: 12px;
        text-decoration: none;
        color: #74c69d;
        font-weight: 700;
        font-size: .88rem;
        letter-spacing: -.3px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-logo span {
        width: 26px; height: 26px;
        background: linear-gradient(135deg, #2d7a4f, #40916c);
        border-radius: 7px;
        display: flex; align-items: center; justify-content: center;
        font-size: 13px;
      }
      #converto-nav-bar .cnav-divider {
        width: 1px; height: 20px;
        background: rgba(64,145,108,0.25);
        margin: 0 8px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-link {
        display: flex;
        align-items: center;
        gap: 5px;
        padding: 5px 11px;
        border-radius: 7px;
        text-decoration: none;
        font-size: .78rem;
        font-weight: 500;
        color: rgba(116,198,157,0.7);
        transition: all .15s;
        white-space: nowrap;
        border: 1px solid transparent;
      }
      #converto-nav-bar .cnav-link:hover {
        background: rgba(45,122,79,0.2);
        color: #74c69d;
        border-color: rgba(64,145,108,0.3);
      }
      #converto-nav-bar .cnav-link.active {
        background: rgba(45,122,79,0.25);
        color: #e8f5ee;
        border-color: rgba(64,145,108,0.4);
        font-weight: 600;
      }
      #converto-nav-bar .cnav-right {
        margin-left: auto;
        display: flex;
        align-items: center;
        gap: 8px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-merchant {
        font-size: .7rem;
        color: rgba(116,198,157,0.5);
        font-family: 'DM Mono', monospace;
        padding: 3px 8px;
        background: rgba(45,122,79,0.1);
        border-radius: 5px;
        border: 1px solid rgba(64,145,108,0.15);
      }
      #converto-nav-bar .cnav-logout {
        padding: 5px 11px;
        border-radius: 7px;
        border: 1px solid rgba(64,145,108,0.2);
        background: none;
        color: rgba(116,198,157,0.6);
        font-size: .75rem;
        cursor: pointer;
        font-family: inherit;
        transition: all .15s;
      }
      #converto-nav-bar .cnav-logout:hover {
        border-color: #ef4444;
        color: #f87171;
      }
    `;

    var styleEl = document.createElement('style');
    styleEl.textContent = css;
    document.head.appendChild(styleEl);

    var nav = document.createElement('div');
    nav.id = 'converto-nav-bar';

    // Logo
    var logo = document.createElement('a');
    logo.className = 'cnav-logo';
    logo.href = BASE + '/hub.html';
    logo.innerHTML = '<span>🔄</span> Converto';
    nav.appendChild(logo);

    // Divider
    var div1 = document.createElement('div');
    div1.className = 'cnav-divider';
    nav.appendChild(div1);

    // Links
    pages.forEach(function(page) {
      if (page.id === 'hub') return; // Hub schon als Logo
      if (page.admin && !isSuperadmin) return; // Superadmin nur für Superadmin

      var a = document.createElement('a');
      a.className = 'cnav-link' + (current === page.id ? ' active' : '');
      a.href = page.url;
      a.textContent = page.label;
      nav.appendChild(a);
    });

    // Right side
    var right = document.createElement('div');
    right.className = 'cnav-right';

    if (slug && current !== 'hub' && current !== 'superadmin') {
      var merchantBadge = document.createElement('span');
      merchantBadge.className = 'cnav-merchant';
      merchantBadge.textContent = '📍 ' + slug;
      right.appendChild(merchantBadge);
    }

    var logoutBtn = document.createElement('button');
    logoutBtn.className = 'cnav-logout';
    logoutBtn.textContent = '← Hub';
    logoutBtn.onclick = function() { window.location.href = BASE + '/hub.html'; };
    right.appendChild(logoutBtn);

    nav.appendChild(right);
    document.body.insertBefore(nav, document.body.firstChild);

    // Bestehenden Nav nach unten verschieben
    adjustPageLayout();
  }

  function adjustPageLayout() {
    // Existierende fixe Navbars nach unten schieben
    setTimeout(function() {
      var existingNav = document.querySelector('nav.nav, nav[style*="fixed"], nav[style*="sticky"]');
      if (existingNav) {
        var currentTop = parseInt(existingNav.style.top) || 0;
        existingNav.style.top = (currentTop + 48) + 'px';
      }

      // App-Layout anpassen
      var appLayout = document.getElementById('appLayout');
      if (appLayout) {
        var currentMargin = parseInt(appLayout.style.marginTop) || 52;
        appLayout.style.marginTop = (currentMargin + 48) + 'px';
        var currentHeight = appLayout.style.height;
        if (currentHeight && currentHeight.includes('calc')) {
          appLayout.style.height = 'calc(100vh - ' + (currentMargin + 48) + 'px)';
        }
      }

      // Body padding falls nötig
      if (!existingNav && !appLayout) {
        document.body.style.paddingTop = '48px';
      }
    }, 50);
  }

  // Warte auf DOM
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildNav);
  } else {
    buildNav();
  }

})();
