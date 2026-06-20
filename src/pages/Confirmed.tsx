import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useT } from '../lib/i18n'

// Landing page for the email-confirmation link. The link signs the user in (the
// token is in the URL), so we sign them back out and ask them to log in with their
// password — a clean, intentional sign-in on the device they'll actually use.
// Because the link often opens in a NEW tab (from the email app), we also offer a
// "close this window" action and point them back to portal.ktcterminal.com.
export default function Confirmed() {
  const { signOut } = useAuth()
  const { t } = useT()
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)
  const [cantClose, setCantClose] = useState(false)

  async function continueToLogin() {
    setBusy(true)
    await signOut()
    sessionStorage.setItem('ktc_email_confirmed', '1')
    navigate('/login', { replace: true })
  }

  function closeWindow() {
    window.close()
    // Browsers only allow window.close() on script-opened windows; if this tab
    // was opened by the email app it won't close, so guide the user instead.
    setTimeout(() => setCantClose(true), 250)
  }

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100%', padding: 24 }}>
      <div className="ktc-glass" style={{ width: '100%', maxWidth: 440, padding: '36px 36px 32px', textAlign: 'center' }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 56, marginBottom: 18 }} />
        <div style={{ fontSize: 40, lineHeight: 1, marginBottom: 8 }}>✓</div>
        <h1 style={{ margin: 0, fontSize: 23, fontWeight: 600, letterSpacing: '-0.02em' }}>{t('Email confirmed')}</h1>
        <p className="ktc-label" style={{ marginTop: 10, lineHeight: 1.6 }}>
          {t('Thanks — your email address is verified. You can close this window and sign in at portal.ktcterminal.com to continue and upload your valid ID.')}
        </p>
        <button className="ktc-btn" type="button" disabled={busy} onClick={() => void continueToLogin()} style={{ marginTop: 18, width: '100%' }}>
          {busy ? t('Please wait…') : t('Sign in here')}
        </button>
        <button className="ktc-btn-secondary" type="button" onClick={closeWindow} style={{ marginTop: 10, width: '100%' }}>
          {t('Close this window')}
        </button>
        {cantClose && (
          <p className="ktc-label" style={{ marginTop: 12, fontSize: 12.5, opacity: 0.85, lineHeight: 1.5 }}>
            {t('You can now close this tab and sign in at portal.ktcterminal.com.')}
          </p>
        )}
      </div>
    </div>
  )
}
