/**
 * Converto Navigation Bar v2
 */
(function() {

  var BASE = 'https://officepuertoplata-coder.github.io/sosuapesce';

  function getSlug() {
    return new URLSearchParams(window.location.search).get('m') || 'sosuapesce';
  }

  function getCurrentPage() {
    var path = window.location.pathname;
    if (path.includes('comm.html'))             return 'comm';
    if (path.includes('haendler-session.html')) return 'haendler-session';
    if (path.includes('orders.html'))           return 'orders';
    if (path.includes('admin.html'))            return 'admin';
    if (path.includes('agentes.html'))          return 'agentes';
    if (path.includes('superadmin.html'))       return 'superadmin';
    if (path.includes('dashboard.html'))        return 'dashboard';
    if (path.includes('hub.html'))              return 'hub';
    return '';
  }

  function buildNav() {
    var slug = getSlug();
    var current = getCurrentPage();

    var auth = null;
    try { auth = JSON.parse(localStorage.getItem('converto_auth_v2') || 'null'); } catch(e) {}
    var isSuperadmin = auth && auth.role === 'superadmin';

    var pages = [
      { id: 'comm',             label: '💬 Kommunikation',   url: BASE + '/comm.html?m=' + slug       },
      { id: 'haendler-session', label: '📋 Verfügbarkeit',   url: BASE + '/haendler-session.html'     },
      { id: 'orders',           label: '📦 Bestellungen',    url: BASE + '/orders.html'               },
      { id: 'agentes',          label: '👥 Agenten',         url: BASE + '/agentes.html?m=' + slug    },
      { id: 'admin',            label: '⚙️ Admin',            url: BASE + '/admin.html?m=' + slug      },
      { id: 'superadmin',       label: '👑 Super',           url: BASE + '/superadmin.html', admin: true },
    ];

    var css = `
      #converto-nav-bar {
        position: fixed;
        top: 0; left: 0; right: 0;
        height: 48px;
        background: #0d2818;
        border-bottom: 1px solid rgba(64,145,108,0.25);
        display: flex;
        align-items: center;
        padding: 0 12px;
        gap: 2px;
        z-index: 9999;
        font-family: 'DM Sans', 'Segoe UI', sans-serif;
        box-shadow: 0 2px 12px rgba(0,0,0,0.3);
        overflow: hidden;
      }
      #converto-nav-bar .cnav-logo {
        display: flex;
        align-items: center;
        gap: 6px;
        margin-right: 8px;
        text-decoration: none;
        color: #74c69d;
        font-weight: 700;
        font-size: .82rem;
        letter-spacing: -.3px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-logo span {
        width: 24px; height: 24px;
        background: linear-gradient(135deg, #2d7a4f, #40916c);
        border-radius: 6px;
        display: flex; align-items: center; justify-content: center;
        font-size: 12px;
      }
      #converto-nav-bar .cnav-divider {
        width: 1px; height: 18px;
        background: rgba(64,145,108,0.25);
        margin: 0 6px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-link {
        display: flex;
        align-items: center;
        padding: 4px 8px;
        border-radius: 6px;
        text-decoration: none;
        font-size: .72rem;
        font-weight: 500;
        color: rgba(116,198,157,0.6);
        transition: all .15s;
        white-space: nowrap;
        border: 1px solid transparent;
      }
      #converto-nav-bar .cnav-link:hover {
        background: rgba(45,122,79,0.2);
        color: #74c69d;
      }
      #converto-nav-bar .cnav-link.active {
        background: rgba(45,122,79,0.25);
        color: #e8f5ee;
        border-color: rgba(64,145,108,0.3);
        font-weight: 600;
      }
      #converto-nav-bar .cnav-right {
        margin-left: auto;
        display: flex;
        align-items: center;
        gap: 6px;
        flex-shrink: 0;
      }
      #converto-nav-bar .cnav-merchant {
        font-size: .65rem;
        color: rgba(116,198,157,0.4);
        font-family: monospace;
        padding: 2px 6px;
        background: rgba(45,122,79,0.1);
        border-radius: 4px;
        border: 1px solid rgba(64,145,108,0.12);
      }
      #converto-nav-bar .cnav-hub {
        padding: 4px 10px;
        border-radius: 6px;
        border: 1px solid rgba(64,145,108,0.2);
        background: none;
        color: rgba(116,198,157,0.6);
        font-size: .7rem;
        cursor: pointer;
        font-family: inherit;
        transition: all .15s;
      }
      #converto-nav-bar .cnav-hub:hover {
        border-color: rgba(116,198,157,0.4);
        color: #74c69d;
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

    var div1 = document.createElement('div');
    div1.className = 'cnav-divider';
    nav.appendChild(div1);

    // Links
    pages.forEach(function(page) {
      if (page.admin && !isSuperadmin) return;
      var a = document.createElement('a');
      a.className = 'cnav-link' + (current === page.id ? ' active' : '');
      a.href = page.url;
      a.textContent = page.label;
      nav.appendChild(a);
    });

    // Right
    var right = document.createElement('div');
    right.className = 'cnav-right';

    if (slug && current !== 'hub') {
      var badge = document.createElement('span');
      badge.className = 'cnav-merchant';
      badge.textContent = slug;
      right.appendChild(badge);
    }

    var hubBtn = document.createElement('button');
    hubBtn.className = 'cnav-hub';
    hubBtn.textContent = '← Hub';
    hubBtn.onclick = function() { window.location.href = BASE + '/hub.html'; };
    right.appendChild(hubBtn);

    nav.appendChild(right);
    document.body.insertBefore(nav, document.body.firstChild);

    // Layout anpassen
    setTimeout(function() {
      var existingNav = document.querySelector('.nav');
      if (existingNav && existingNav.style) {
        var top = parseInt(existingNav.style.top) || 0;
        existingNav.style.top = (top + 48) + 'px';
      }
      var appLayout = document.getElementById('appLayout');
      if (appLayout) {
        var mt = parseInt(appLayout.style.marginTop) || 52;
        appLayout.style.marginTop = (mt + 48) + 'px';
        appLayout.style.height = 'calc(100vh - ' + (mt + 48) + 'px)';
      }
      if (!document.getElementById('appLayout') && !document.querySelector('.nav')) {
        document.body.style.paddingTop = (parseInt(document.body.style.paddingTop)||0) + 'px';
      }
    }, 50);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildNav);
  } else {
    buildNav();
  }

})();
