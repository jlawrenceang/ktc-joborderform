import { useCallback, useEffect, useRef, useState } from 'react'

/**
 * Auto-refresh + rate-limited manual refresh for status displays.
 *  - Runs `fn` every `intervalMs` (default 60s) while the tab is VISIBLE,
 *    and once immediately when the tab becomes visible again — so statuses
 *    stay fresh without hammering the backend from idle tabs.
 *  - `refresh()` is the manual trigger, allowed once per `cooldownMs`
 *    (default 10s); `cooling` is true during the cooldown for disabling
 *    the button.
 */
export function useAutoRefresh(
  fn: () => void | Promise<void>,
  { intervalMs = 60_000, cooldownMs = 10_000, enabled = true } = {},
) {
  const fnRef = useRef(fn)
  fnRef.current = fn
  const lastManual = useRef(0)
  const [cooling, setCooling] = useState(false)

  useEffect(() => {
    if (!enabled) return
    const id = setInterval(() => {
      if (document.visibilityState === 'visible') void fnRef.current()
    }, intervalMs)
    const onVisible = () => {
      if (document.visibilityState === 'visible') void fnRef.current()
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      clearInterval(id)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [intervalMs, enabled])

  const refresh = useCallback(() => {
    const now = Date.now()
    if (now - lastManual.current < cooldownMs) return
    lastManual.current = now
    setCooling(true)
    const t = setTimeout(() => setCooling(false), cooldownMs)
    void fnRef.current()
    return () => clearTimeout(t)
  }, [cooldownMs])

  return { refresh, cooling }
}
