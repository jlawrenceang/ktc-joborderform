import { useEffect, useState } from 'react'

// Light/dark toggle. The pre-paint script in index.html sets the initial theme
// from localStorage('ktc-theme') ('light'|'dark'|'system', default system).
// Clicking sets an explicit choice; if left on 'system' it tracks the OS.
function isDarkNow(): boolean {
  return document.documentElement.getAttribute('data-theme') === 'dark'
}

const Sun = (
  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
  </svg>
)
const Moon = (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    <path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z" />
  </svg>
)

export default function ThemeToggle() {
  const [dark, setDark] = useState(isDarkNow)

  // Track the OS while the user is still on 'system'.
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => {
      if ((localStorage.getItem('ktc-theme') || 'system') !== 'system') return
      const d = mq.matches
      document.documentElement.setAttribute('data-theme', d ? 'dark' : 'light')
      setDark(d)
    }
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  function toggle() {
    const next = !dark
    document.documentElement.setAttribute('data-theme', next ? 'dark' : 'light')
    try { localStorage.setItem('ktc-theme', next ? 'dark' : 'light') } catch { /* ignore */ }
    setDark(next)
  }

  return (
    <button type="button" className="ktc-theme-toggle" onClick={toggle}
      title={dark ? 'Switch to light mode' : 'Switch to dark mode'} aria-label="Toggle dark mode" aria-pressed={dark}>
      {dark ? Sun : Moon}
    </button>
  )
}
