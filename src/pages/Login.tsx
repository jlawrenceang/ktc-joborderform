import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import Turnstile, { captchaEnabled } from '../components/Turnstile'
import {
  IRR_VERSION, IRR_VERSION_LABEL,
  TERMS_VERSION, TERMS_VERSION_LABEL,
  PRIVACY_VERSION, PRIVACY_VERSION_LABEL,
} from '../content/legal'

export default function Login() {
  const { signIn, signUp } = useAuth()
  const navigate = useNavigate()
  const [mode, setMode] = useState<'signin' | 'signup'>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [idFile, setIdFile] = useState<File | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [agreedTerms, setAgreedTerms] = useState(false) // Terms & Conditions + Broker IRR
  const [consentPrivacy, setConsentPrivacy] = useState(false) // DPA data-privacy consent
  // bumping this remounts the widget, forcing a fresh single-use token
  const [captchaKey, setCaptchaKey] = useState(0)

  function resetCaptcha() {
    setCaptchaToken(null)
    setCaptchaKey((k) => k + 1)
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (mode === 'signup' && !agreedTerms) {
      setError('Please read and accept the Terms & Conditions and Broker IRR to continue.')
      return
    }
    if (mode === 'signup' && !consentPrivacy) {
      setError('Please give your data-privacy consent to continue.')
      return
    }
    if (captchaEnabled && !captchaToken) {
      setError('Please complete the CAPTCHA.')
      return
    }
    setBusy(true)
    setError(null)
    setNotice(null)
    const token = captchaToken ?? undefined
    const res =
      mode === 'signin'
        ? await signIn(email, password, token)
        : await signUp(email, password, {
            fullName,
            idFile,
            captchaToken: token,
            irrVersion: IRR_VERSION,
            termsVersion: TERMS_VERSION,
            privacyVersion: PRIVACY_VERSION,
          })
    setBusy(false)
    // tokens are single-use — always reset after an attempt
    if (captchaEnabled) resetCaptcha()
    if (res.error) {
      setError(res.error)
      return
    }
    if (mode === 'signup') {
      setNotice('Account created. If email confirmation is on, confirm via email, then sign in.')
      setMode('signin')
      setFullName('')
      setIdFile(null)
      setAgreedTerms(false)
      setConsentPrivacy(false)
      return
    }
    navigate('/', { replace: true })
  }

  const isSignup = mode === 'signup'

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100%', padding: 24 }}>
      <div className="ktc-glass" style={{ width: '100%', maxWidth: 440, padding: '36px 36px 32px' }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 64, marginBottom: 20 }} />
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em' }}>
          {isSignup ? 'Create account' : 'Sign in'}
        </h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 24 }}>
          KTC Job Order portal — for accredited brokers.
        </p>

        <form onSubmit={onSubmit} style={{ display: 'grid', gap: 14 }}>
          {isSignup && (
            <div style={{ display: 'grid', gap: 6 }}>
              <label className="ktc-label" htmlFor="fullName">Full name</label>
              <input id="fullName" className="ktc-input" type="text" required value={fullName}
                onChange={(e) => setFullName(e.target.value)} autoComplete="name" />
            </div>
          )}

          <div style={{ display: 'grid', gap: 6 }}>
            <label className="ktc-label" htmlFor="email">{isSignup ? 'Email' : 'Email or username'}</label>
            <input id="email" className="ktc-input" type={isSignup ? 'email' : 'text'} required value={email}
              onChange={(e) => setEmail(e.target.value)} autoComplete="username" />
          </div>

          <div style={{ display: 'grid', gap: 6 }}>
            <label className="ktc-label" htmlFor="password">Password</label>
            <input id="password" className="ktc-input" type="password" required minLength={6} value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={isSignup ? 'new-password' : 'current-password'} />
          </div>

          {isSignup && (
            <div style={{ display: 'grid', gap: 6 }}>
              <label className="ktc-label" htmlFor="validId">Valid ID (image or PDF)</label>
              <input id="validId" className="ktc-input" type="file" accept="image/*,application/pdf"
                onChange={(e) => setIdFile(e.target.files?.[0] ?? null)} required
                style={{ padding: '9px 13px' }} />
              <span className="ktc-label" style={{ fontSize: 12, opacity: 0.8 }}>
                Uploaded securely; only KTC admins can view it.
              </span>
            </div>
          )}

          {isSignup && (
            <div style={{ display: 'grid', gap: 10 }}>
              <label style={{ display: 'flex', gap: 9, alignItems: 'flex-start', fontSize: 13, lineHeight: 1.5 }}>
                <input
                  type="checkbox"
                  checked={agreedTerms}
                  onChange={(e) => setAgreedTerms(e.target.checked)}
                  style={{ marginTop: 2, flex: '0 0 auto' }}
                  required
                />
                <span className="ktc-label" style={{ fontSize: 13 }}>
                  I have read and agree to the{' '}
                  <Link to="/terms" target="_blank" className="ktc-link">Terms &amp; Conditions ({TERMS_VERSION_LABEL})</Link>{' '}
                  and the{' '}
                  <Link to="/irr" target="_blank" className="ktc-link">Broker IRR ({IRR_VERSION_LABEL})</Link>.
                </span>
              </label>
              <label style={{ display: 'flex', gap: 9, alignItems: 'flex-start', fontSize: 13, lineHeight: 1.5 }}>
                <input
                  type="checkbox"
                  checked={consentPrivacy}
                  onChange={(e) => setConsentPrivacy(e.target.checked)}
                  style={{ marginTop: 2, flex: '0 0 auto' }}
                  required
                />
                <span className="ktc-label" style={{ fontSize: 13 }}>
                  I consent to KTC collecting and processing my personal data, including the valid ID I upload,
                  in accordance with the{' '}
                  <Link to="/privacy" target="_blank" className="ktc-link">Privacy Notice ({PRIVACY_VERSION_LABEL})</Link>{' '}
                  (Data Privacy Act of 2012).
                </span>
              </label>
            </div>
          )}

          {captchaEnabled && (
            <Turnstile
              key={captchaKey}
              onVerify={(t) => setCaptchaToken(t)}
              onExpire={() => setCaptchaToken(null)}
            />
          )}

          {error && <div style={{ color: 'var(--acc-2)', fontSize: 13 }}>{error}</div>}
          {notice && <div className="ktc-label" style={{ fontSize: 13 }}>{notice}</div>}

          <button className="ktc-btn" type="submit" disabled={busy || (captchaEnabled && !captchaToken) || (isSignup && (!agreedTerms || !consentPrivacy))} style={{ marginTop: 6 }}>
            {busy ? 'Please wait…' : isSignup ? 'Sign up' : 'Sign in'}
          </button>
        </form>

        <p className="ktc-label" style={{ marginTop: 18, fontSize: 13 }}>
          {isSignup ? 'Already have an account? ' : "Don't have an account? "}
          <button className="ktc-link" type="button"
            onClick={() => { setMode(isSignup ? 'signin' : 'signup'); setError(null); setNotice(null); resetCaptcha(); setAgreedTerms(false); setConsentPrivacy(false) }}>
            {isSignup ? 'Sign in' : 'Create one'}
          </button>
        </p>

        <p className="ktc-label" style={{ marginTop: 14, fontSize: 12, opacity: 0.85, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          <Link to="/terms" className="ktc-link">Terms</Link>
          <Link to="/privacy" className="ktc-link">Privacy</Link>
          <Link to="/irr" className="ktc-link">Broker IRR</Link>
        </p>
      </div>
    </div>
  )
}
