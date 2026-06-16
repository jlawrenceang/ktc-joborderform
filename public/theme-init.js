// Set the theme before first paint to avoid a flash. 'system' follows the OS.
// External (not inline) so it satisfies the CSP script-src 'self' directive —
// an inline <script> would be blocked.
(function () {
  try {
    var pref = localStorage.getItem('ktc-theme') || 'system';
    var dark = pref === 'dark' || (pref === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
  } catch (e) { /* default light */ }
})();
