import { useEffect, useRef } from 'react'

// Sign the user out after `ms` of no interaction. Any of the listed activity
// events resets the countdown. The callback is kept in a ref so changing its
// identity each render doesn't re-arm the listeners.
const ACTIVITY_EVENTS = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'] as const

export function useIdleLogout(onIdle: () => void, ms: number) {
  const cb = useRef(onIdle)
  cb.current = onIdle

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>
    let last = 0
    const arm = () => {
      clearTimeout(timer)
      timer = setTimeout(() => cb.current(), ms)
    }
    const onActivity = () => {
      // Throttle: at most one re-arm per second (mousemove can fire constantly).
      const now = Date.now()
      if (now - last < 1000) return
      last = now
      arm()
    }
    ACTIVITY_EVENTS.forEach((e) => window.addEventListener(e, onActivity, { passive: true }))
    arm()
    return () => {
      clearTimeout(timer)
      ACTIVITY_EVENTS.forEach((e) => window.removeEventListener(e, onActivity))
    }
  }, [ms])
}
