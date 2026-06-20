import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { useBroker } from '../lib/useBroker'
import { useT } from '../lib/i18n'

// Owner-only tool: send a real test of the branded portal email templates to any
// address (via the owner_send_test_email RPC, migration 0122 → send_portal_email).
const TEMPLATES: { key: string; label: string }[] = [
  { key: 'notification', label: 'Notification nudge (the live customer email)' },
  { key: 'approved', label: 'Account approved' },
  { key: 'on_hold', label: 'Job Order on hold' },
  { key: 'rejected', label: 'Job Order update / rejection' },
  { key: 'payment', label: 'Payment update' },
]

export default function TestEmailCard() {
  const { t } = useT()
  const { broker } = useBroker()
  const [to, setTo] = useState(broker?.email ?? '')
  const [template, setTemplate] = useState('notification')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState<string | null>(null)
  const [err, setErr] = useState<string | null>(null)

  async function send() {
    const addr = to.trim()
    if (!addr || !addr.includes('@')) { setErr(t('Enter a valid recipient email address.')); return }
    setBusy(true); setErr(null); setMsg(null)
    const { error } = await supabase.rpc('owner_send_test_email', { p_to: addr, p_template: template })
    setBusy(false)
    if (error) { setErr(error.message); return }
    setMsg(t('Test email sent to {to} — check the inbox (and spam).', { to: addr }))
  }

  return (
    <div className="ktc-glass" style={{ padding: 18, marginBottom: 18 }}>
      <h2 style={{ margin: 0, fontSize: 15, fontWeight: 600 }}>{t('Test email templates')}</h2>
      <p className="ktc-sub" style={{ margin: '2px 0 12px', fontSize: 12 }}>
        {t('Send a real test of the branded portal email to any address to check rendering + delivery.')}
      </p>
      <div style={{ display: 'grid', gap: 10, maxWidth: 420 }}>
        <input className="ktc-input ktc-input--compact" type="email" value={to} onChange={(e) => setTo(e.target.value)} placeholder={t('Recipient email')} />
        <select className="ktc-input ktc-input--compact" value={template} onChange={(e) => setTemplate(e.target.value)}>
          {TEMPLATES.map((tpl) => <option key={tpl.key} value={tpl.key}>{t(tpl.label)}</option>)}
        </select>
        <button className="ktc-btn ktc-btn--sm" type="button" disabled={busy} onClick={() => void send()}
          style={{ width: 'auto', padding: '8px 16px', fontSize: 13, justifySelf: 'start' }}>
          {busy ? t('Sending…') : t('Send test email')}
        </button>
      </div>
      {msg && <div className="ktc-label" style={{ marginTop: 10, fontSize: 12.5 }}>{msg}</div>}
      {err && <div style={{ marginTop: 10, color: 'var(--acc-2)', fontSize: 12.5 }}>{err}</div>}
    </div>
  )
}
