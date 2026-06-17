// Register the service worker (Web Push + conservative app caching). Kept
// side-effect-light: we do NOT force a reload on update — a new SW activates on
// the next navigation, and the app's existing stale-chunk recovery handles any
// chunk mismatch. The SW is optional; the app works fine without it.
export function registerSW() {
  if (typeof navigator === 'undefined' || !('serviceWorker' in navigator)) return
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').then((reg) => {
      reg.addEventListener('updatefound', () => {
        const sw = reg.installing
        if (!sw) return
        sw.addEventListener('statechange', () => {
          // New version installed alongside the current one → let it take over
          // so the update applies on the next load (no disruptive auto-reload).
          if (sw.state === 'installed' && navigator.serviceWorker.controller) {
            reg.waiting?.postMessage('SKIP_WAITING')
          }
        })
      })
    }).catch(() => { /* ignore — SW is an enhancement, not required */ })
  })
}
