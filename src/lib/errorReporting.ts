import { supabase } from './supabase'

// Client-side error reporting → log_client_error RPC → app_errors table
// (surfaced in Settings → System health; watchdog emails the owner on a
// spike). Throttled hard: reporting must never become its own problem.

const seen = new Set<string>()
let windowStart = Date.now()
let sentThisWindow = 0

const IGNORE = [
  'ResizeObserver loop', // benign browser noise
  'Script error.',       // opaque cross-origin errors carry no signal
]

function report(message: string, stack?: string | null) {
  try {
    if (!message || IGNORE.some((m) => message.includes(m))) return
    const now = Date.now()
    if (now - windowStart > 60_000) {
      windowStart = now
      sentThisWindow = 0
    }
    if (sentThisWindow >= 5) return
    const key = message.slice(0, 200)
    if (seen.has(key)) return // once per distinct error per session
    seen.add(key)
    sentThisWindow++
    // Must attach .then() — a bare `void supabase.rpc(...)` is a lazy builder
    // that never dispatches the request (the report would silently never send).
    supabase
      .rpc('log_client_error', {
        p_message: message.slice(0, 500),
        p_stack: stack?.slice(0, 4000) ?? null,
        p_path: window.location.pathname,
        p_ua: navigator.userAgent.slice(0, 300),
      })
      .then(() => undefined, () => undefined)
  } catch {
    // never break the app over reporting
  }
}

export function reportError(err: unknown) {
  const e = err as { message?: string; stack?: string } | null
  report(e?.message ?? String(err), e?.stack)
}

// A failed code-split chunk load — almost always a STALE DEPLOY: this tab was
// open when a new build replaced the hashed asset files, so the old chunk now
// 404s (the SPA rewrite returns index.html → "MIME type text/html" / "Failed to
// fetch dynamically imported module"). The cure is to reload and pick up the
// fresh index.html + chunk hashes.
export function isChunkLoadError(err: unknown): boolean {
  const msg = (err as { message?: string } | null)?.message ?? String(err ?? '')
  // The last alternative — reading 'default' — is the React.lazy symptom of a
  // stale chunk that resolved to undefined (see lazyWithReload); treat it as a
  // chunk error so the boundary auto-reloads instead of showing the error page.
  return /dynamically imported module|module script failed|error loading dynamically imported|Loading (?:CSS )?chunk|ChunkLoadError|Importing a module script failed|reading ['"]default['"]/i.test(msg)
}

// Reload ONCE to recover from a stale chunk. Guarded by a sessionStorage stamp
// so a genuinely-broken build can't trap the page in a reload loop.
export function reloadForStaleChunk(): boolean {
  try {
    const KEY = 'ktc_chunk_reload_at'
    const last = Number(sessionStorage.getItem(KEY) || 0)
    if (Date.now() - last < 20_000) return false // already tried just now — don't loop
    sessionStorage.setItem(KEY, String(Date.now()))
    window.location.reload()
    return true
  } catch {
    return false
  }
}

export function installErrorReporting() {
  // Vite fires this when a lazily-imported chunk fails to load (stale deploy).
  // Auto-recover before it bubbles to the error boundary as a hard crash.
  window.addEventListener('vite:preloadError', (e) => {
    e.preventDefault()
    if (!reloadForStaleChunk()) report('vite:preloadError (reload guard hit)')
  })
  window.addEventListener('error', (e) => {
    report(e.message || 'Unknown error', (e.error as Error | undefined)?.stack)
  })
  window.addEventListener('unhandledrejection', (e) => {
    if (isChunkLoadError(e.reason) && reloadForStaleChunk()) return
    const r = e.reason as { message?: string; stack?: string } | null
    report(r?.message ?? String(e.reason), r?.stack)
  })
}
