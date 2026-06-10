import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'

// Landing page for the email-confirmation link. The link signs the user in (the
// token is in the URL), so we sign them back out and ask them to log in with their
// password — a clean, intentional sign-in on the device they'll actually use.
export default function Confirmed() {
  const { signOut } = useAuth()
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)

  async function continueToLogin() {
    setBusy(true)
    await signOut()
    sessionStorage.setItem('ktc_email_confirmed', '1')
    navigate('/login', { replace: true })
  }

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100%', padding: 24 }}>
      <div className="ktc-glass" style={{ width: '100%', maxWidth: 440, padding: '36px 36px 32px', textAlign: 'center' }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 56, marginBottom: 18 }} />
        <div style={{ fontSize: 40, lineHeight: 1, marginBottom: 8 }}>✓</div>
        <h1 style={{ margin: 0, fontSize: 23, fontWeight: 600, letterSpacing: '-0.02em' }}>Email confirmed</h1>
        <p className="ktc-label" style={{ marginTop: 10, lineHeight: 1.6 }}>
          Thanks — your email address is verified. Please sign in with your password to continue and upload your valid ID.
        </p>
        <button className="ktc-btn" type="button" disabled={busy} onClick={() => void continueToLogin()} style={{ marginTop: 18, width: '100%' }}>
          {busy ? 'Please wait…' : 'Sign in to continue'}
        </button>
      </div>
    </div>
  )
}
