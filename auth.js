/**
 * Converto Central Auth System v2
 * Einmal einloggen - alle Seiten funktionieren automatisch
 */
window.ConvertAuth = (function() {

  var KEY = 'converto_auth_v2';
  var EXPIRY = 30 * 24 * 60 * 60 * 1000;

  function get() {
    try { return JSON.parse(localStorage.getItem(KEY) || 'null'); }
    catch(e) { return null; }
  }

  function save(data) {
    localStorage.setItem(KEY, JSON.stringify({ role: data.role, slug: data.slug, password: data.password, name: data.name, savedAt: Date.now() }));
  }

  function clear() { localStorage.removeItem(KEY); }

  function isValid(s) { return s && s.savedAt && (Date.now() - s.savedAt) < EXPIRY; }

  function getSlug() {
    return new URLSearchParams(window.location.search).get('m') || 'sosuapesce';
  }

  function tryAutoLogin(sb, slug, onSuccess, onFail) {
    var stored = get();
    if (!stored || !isValid(stored)) { if (onFail) onFail(); return; }

    if (stored.role === 'superadmin') {
      var cfg = window.SP_CONFIG;
      if (cfg && stored.password === cfg.SUPERADMIN_PASSWORD) {
        if (onSuccess) onSuccess({ id: null, name: 'Superadmin', slug: slug, role: 'superadmin', admin_password: stored.password });
      } else { clear(); if (onFail) onFail(); }
      return;
    }

    if (stored.slug !== slug) { if (onFail) onFail(); return; }

    sb.from('merchants').select('*').eq('slug', slug).single().then(function(r) {
      if (r.error || !r.data) { clear(); if (onFail) onFail(); return; }
      if (r.data.admin_password !== stored.password) { clear(); if (onFail) onFail(); return; }
      if (onSuccess) onSuccess(r.data);
    });
  }

  function logout() { clear(); window.location.href = 'hub.html'; }

  return { get: get, save: save, clear: clear, isValid: isValid, getSlug: getSlug, tryAutoLogin: tryAutoLogin, logout: logout };

})();
