/**
 * Converto Auth Init - wird auf jeder Seite geladen
 * Übernimmt den Login automatisch vom Hub
 */
(function() {
  var KEY = 'converto_auth_v2';
  var EXPIRY = 30 * 24 * 60 * 60 * 1000;

  function getStored() {
    try { return JSON.parse(localStorage.getItem(KEY) || 'null'); }
    catch(e) { return null; }
  }

  function isValid(s) { return s && s.savedAt && (Date.now() - s.savedAt) < EXPIRY; }

  // Warte bis Seite geladen ist
  window.addEventListener('load', function() {
    var stored = getStored();
    if (!stored || !isValid(stored)) return; // Kein gespeicherter Login

    // Passwort-Feld vorausfüllen wenn Login-Screen sichtbar
    var pwField = document.getElementById('pwInput');
    if (pwField && pwField.value === '') {
      pwField.value = stored.password;

      // Kurz warten dann auto-submit
      setTimeout(function() {
        // Prüfen ob Login-Screen noch sichtbar
        var loginWrap = document.getElementById('loginWrap');
        var loginWrap2 = document.getElementById('loginScreen');
        var loginVisible = (loginWrap && loginWrap.style.display !== 'none') ||
                           (loginWrap2 && loginWrap2.style.display !== 'none');

        if (loginVisible) {
          // Slug setzen wenn vorhanden
          if (stored.slug) {
            var slugParam = new URLSearchParams(window.location.search).get('m');
            if (!slugParam || slugParam === stored.slug) {
              // Auto-Login ausloesen
              if (typeof doLogin === 'function') doLogin();
              else if (typeof window.doLogin === 'function') window.doLogin();
            }
          } else if (stored.role === 'superadmin') {
            if (typeof doLogin === 'function') doLogin();
          }
        }
      }, 300);
    }

    // Logout-Buttons auf alle Seiten-Logouts patchen
    var logoutBtns = document.querySelectorAll('[onclick="doLogout()"], .tbtn-out');
    logoutBtns.forEach(function(btn) {
      btn.onclick = function(e) {
        e.preventDefault();
        localStorage.removeItem(KEY);
        window.location.href = 'hub.html';
      };
    });
  });

  // Global verfuegbar machen
  window.ConvertAuth = {
    get: getStored,
    isValid: isValid,
    clear: function() { localStorage.removeItem(KEY); },
    save: function(data) {
      localStorage.setItem(KEY, JSON.stringify({ role: data.role, slug: data.slug, password: data.password, name: data.name, savedAt: Date.now() }));
    },
    logout: function() {
      localStorage.removeItem(KEY);
      window.location.href = 'hub.html';
    }
  };

})();
