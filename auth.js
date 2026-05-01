/**
 * Converto Auth System
 * Zentrales Login-System für alle Seiten
 * Speichert Anmeldedaten in localStorage
 */

var ConvertAuth = (function() {

  var STORAGE_KEY = 'converto_auth';
  var API_URL = 'https://converto-server-production.up.railway.app';

  // Gespeicherte Anmeldedaten laden
  function getStored() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
    } catch(e) { return null; }
  }

  // Anmeldedaten speichern
  function save(data) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      role: data.role,
      slug: data.slug || null,
      merchant: data.merchant || null,
      password: data.password,
      savedAt: Date.now()
    }));
  }

  // Ausloggen
  function logout() {
    localStorage.removeItem(STORAGE_KEY);
    window.location.href = 'hub.html';
  }

  // Prüfen ob noch gültig (30 Tage)
  function isValid(stored) {
    if (!stored) return false;
    var age = Date.now() - (stored.savedAt || 0);
    return age < 30 * 24 * 60 * 60 * 1000;
  }

  // Login via Railway API
  function login(slug, password, role, callback) {
    fetch(API_URL + '/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ slug: slug, password: password, role: role })
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.success) {
        save({ role: role, slug: slug, merchant: data.merchant, password: password });
        callback(null, data);
      } else {
        callback(data.error || 'Falsches Passwort');
      }
    })
    .catch(function(e) {
      callback('Verbindungsfehler: ' + e.message);
    });
  }

  // Seite schützen – leitet zu hub.html wenn nicht eingeloggt
  // requiredRole: 'superadmin' | 'merchant' | null (beide erlaubt)
  function requireAuth(requiredRole, onSuccess) {
    var stored = getStored();
    if (!stored || !isValid(stored)) {
      // Zurück zu hub mit Redirect-Info
      window.location.href = 'hub.html?redirect=' + encodeURIComponent(window.location.href);
      return;
    }
    if (requiredRole === 'superadmin' && stored.role !== 'superadmin') {
      window.location.href = 'hub.html?error=noaccess';
      return;
    }
    if (onSuccess) onSuccess(stored);
  }

  // Logout-Button zu einer Seite hinzufügen
  function addLogoutButton(container) {
    var stored = getStored();
    if (!stored) return;
    var btn = document.createElement('button');
    btn.textContent = 'Ausloggen';
    btn.onclick = logout;
    btn.style.cssText = 'background:rgba(255,255,255,0.1);border:none;color:rgba(255,255,255,0.7);padding:6px 14px;border-radius:6px;cursor:pointer;font-size:.82rem;';
    if (container) container.appendChild(btn);
    return btn;
  }

  return {
    getStored: getStored,
    save: save,
    logout: logout,
    isValid: isValid,
    login: login,
    requireAuth: requireAuth,
    addLogoutButton: addLogoutButton
  };

})();
