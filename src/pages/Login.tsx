import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'

export default function Login() {
  const { signIn, signUp } = useAuth()
  const navigate = useNavigate()
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    setNotice(null)
    const fn = mode === 'signin' ? signIn : signUp
    const { error } = await fn(email, password)
    setBusy(false)
    if (error) {
      setError(error)
      return
    }
    if (mode === 'signup') {
      setNotice('Account created. Check your email if confirmation is required, then sign in.')
      setMode('signin')
      return
    }
    navigate('/', { replace: true })
  }

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100%', padding: 24 }}>
      <div className="ktc-glass" style={{ width: '100%', maxWidth: 420, padding: '36px 36px 32px' }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 64, marginBottom: 20 }} />
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em' }}>
          {mode === 'signin' ? 'Sign in' : 'Create account'}
        </h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 24 }}>
          KTC Job Order portal — for accredited brokers.
        </p>

        <form onSubmit={onSubmit} style={{ display: 'grid', gap: 14 }}>
          <div style={{ display: 'grid', gap: 6 }}>
            <label className="ktc-label" htmlFor="email">Email</label>
            <input id="email" className="ktc-input" type="email" required value={email}
              onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
          </div>
          <div style={{ display: 'grid', gap: 6 }}>
            <label className="ktc-label" htmlFor="password">Password</label>
            <input id="password" className="ktc-input" type="password" required minLength={6} value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} />
          </div>

          {error && <div style={{ color: 'var(--acc-2)', fontSize: 13 }}>{error}</div>}
          {notice && <div className="ktc-label" style={{ fontSize: 13 }}>{notice}</div>}

          <button className="ktc-btn" type="submit" disabled={busy} style={{ marginTop: 6 }}>
            {busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Sign up'}
          </button>
        </form>

        <p className="ktc-label" style={{ marginTop: 18, fontSize: 13 }}>
          {mode === 'signin' ? "Don't have an account? " : 'Already have an account? '}
          <button className="ktc-link" type="button"
            onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError(null); setNotice(null) }}>
            {mode === 'signin' ? 'Create one' : 'Sign in'}
          </button>
        </p>
      </div>
    </div>
  )
}
