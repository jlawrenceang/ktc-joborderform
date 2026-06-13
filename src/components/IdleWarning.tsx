// "Still there?" prompt shown ~1 minute before the idle auto-sign-out.
// There is intentionally no onClick handler: ANY click, keypress or mouse
// movement — including pressing this button — bubbles to the window-level
// activity listeners in useIdleLogout, which reset the timer and clear the
// warning. The button just gives the user an obvious thing to click.
import { useT } from '../lib/i18n'

export default function IdleWarning() {
  const { t } = useT()
  return (
    <div className="ktc-modal-backdrop" role="alertdialog" aria-live="assertive" aria-label={t('Inactivity warning')}>
      <div className="ktc-glass-thick ktc-modal-panel" style={{ maxWidth: 400, padding: '26px 24px', textAlign: 'center' }}>
        <div style={{ fontSize: 30, lineHeight: 1 }} aria-hidden>⏰</div>
        <b style={{ display: 'block', margin: '10px 0 4px', fontSize: 16 }}>{t('Are you still there?')}</b>
        <p style={{ margin: '0 0 16px', fontSize: 13.5, opacity: 0.85 }}>
          {t('You’ve been inactive for a while — you’ll be signed out in about a minute.')}
        </p>
        <button className="ktc-btn">{t('I’m still here — keep me signed in')}</button>
      </div>
    </div>
  )
}
