import { lazy, type ComponentType } from 'react'
import { isChunkLoadError, reloadForStaleChunk } from './errorReporting'

// React.lazy with stale-deploy + transient-failure recovery.
//
// Two failure modes when navigating to a not-yet-loaded route:
//   1. STALE DEPLOY — a new build shipped while this tab was open, so the old
//      hashed chunk now 404s. The import either rejects ("Failed to fetch
//      dynamically imported module") or, after Vite's preloadError handler
//      preventDefaults it, RESOLVES TO undefined — which makes React.lazy throw
//      "Cannot read properties of undefined (reading 'default')" and the error
//      boundary show "Something went wrong".
//   2. TRANSIENT — a flaky gate connection times out the chunk fetch.
//
// Recover from both without the error page: reload ONCE for a stale build (the
// fresh index.html carries the new chunk hashes), retry ONCE for a transient
// blip. Only a genuine, repeated failure reaches the error boundary.
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- mirror React.lazy's
// own signature so each route keeps its exact prop types (e.g. the `app` prop).
export function lazyWithReload<T extends ComponentType<any>>(factory: () => Promise<{ default: T }>) {
  return lazy(async () => {
    try {
      const mod = await factory()
      // Guard the resolve-to-undefined case before React.lazy reads `.default`.
      if (!mod || !mod.default) {
        if (reloadForStaleChunk()) return await new Promise<never>(() => {}) // hold the loading state until reload
      }
      return mod
    } catch (err) {
      // Stale deploy → reload once to pick up fresh chunk hashes.
      if (isChunkLoadError(err) && reloadForStaleChunk()) {
        return await new Promise<never>(() => {})
      }
      // Transient (timeout/network) → brief pause, then one retry.
      await new Promise((r) => setTimeout(r, 900))
      return await factory()
    }
  })
}
