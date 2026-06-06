import { useEffect, useRef } from 'react'

// Cloudflare Turnstile — invisible/managed CAPTCHA. The site key is public
// (safe to inline). The matching SECRET key lives only in Supabase Auth.
export const TURNSTILE_SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY
export const captchaEnabled = !!TURNSTILE_SITE_KEY

const SCRIPT_SRC =
  'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, opts: Record<string, unknown>) => string
      reset: (id?: string) => void
      remove: (id?: string) => void
    }
  }
}

function loadScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.turnstile) return resolve()
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT_SRC}"]`)
    if (existing) {
      existing.addEventListener('load', () => resolve())
      existing.addEventListener('error', () => reject(new Error('turnstile failed to load')))
      return
    }
    const s = document.createElement('script')
    s.src = SCRIPT_SRC
    s.async = true
    s.defer = true
    s.onload = () => resolve()
    s.onerror = () => reject(new Error('turnstile failed to load'))
    document.head.appendChild(s)
  })
}

interface Props {
  onVerify: (token: string) => void
  onExpire?: () => void
}

export default function Turnstile({ onVerify, onExpire }: Props) {
  const ref = useRef<HTMLDivElement>(null)
  const widgetId = useRef<string | null>(null)

  useEffect(() => {
    if (!TURNSTILE_SITE_KEY) return
    let cancelled = false
    loadScript()
      .then(() => {
        if (cancelled || !ref.current || !window.turnstile) return
        widgetId.current = window.turnstile.render(ref.current, {
          sitekey: TURNSTILE_SITE_KEY,
          callback: (token: string) => onVerify(token),
          'expired-callback': () => onExpire?.(),
          'error-callback': () => onExpire?.(),
        })
      })
      .catch(() => {})
    return () => {
      cancelled = true
      if (widgetId.current && window.turnstile) {
        try {
          window.turnstile.remove(widgetId.current)
        } catch {
          /* widget already gone */
        }
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  if (!TURNSTILE_SITE_KEY) return null
  return <div ref={ref} style={{ minHeight: 65 }} />
}
