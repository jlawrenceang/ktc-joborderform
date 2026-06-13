import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import type { Broker } from '../lib/types'
import { SUPPORT_EMAIL, SUPPORT_PHONE, SUPPORT_PHONE_TEL } from '../lib/contact'
import { useT } from '../lib/i18n'
import Notice from './Notice'

// Inline banner shown at the top of the portal to a confirmed-but-not-yet-approved
// customer. They get full access to browse and prepare job orders (submit is gated
// server-side). Here we (1) sync consent captured at sign-up, and (2) point them to
// the /verify-id page to upload the valid ID an admin needs before approving.
export default function BrokerStatusBanner({ broker, onRefresh, refreshCooling }: { broker: Broker; onRefresh?: () => void; refreshCooling?: boolean }) {
  const { t } = useT()
  const synced = useRef(false)

  // Sync consent (captured in auth metadata at sign-up) onto the customer row if it
  // wasn't written then (the email-confirmation-on path has no session at sign-up).
  useEffect(() => {
    if (synced.current || broker.terms_version) return
    synced.current = true
    void (async () => {
      const { data } = await supabase.auth.getUser()
      const m = (data.user?.user_metadata ?? {}) as Record<string, unknown>
      const keys = ['irr_version', 'irr_accepted_at', 'terms_version', 'terms_accepted_at', 'privacy_consent_version', 'privacy_consented_at']
      const updates: Record<string, unknown> = {}
      for (const k of keys) if (m[k]) updates[k] = m[k]
      if (Object.keys(updates).length) await supabase.from('customers').update(updates).eq('user_id', broker.user_id)
    })()
  }, [broker.terms_version, broker.user_id])

  const needsId = !broker.valid_id_path

  return (
    <Notice
      tone={needsId ? 'warning' : 'info'}
      badge={t('PENDING FINAL VERIFICATION')}
      title={needsId ? t('Upload your valid ID to get verified') : t('Your account is awaiting admin verification')}
      style={{ marginBottom: 18 }}
      action={
        needsId ? (
          <Link to="/verify-id" style={{
            display: 'inline-block', padding: '9px 16px', borderRadius: 10,
            fontWeight: 600, fontSize: 13, textDecoration: 'none', color: '#fff',
            background: 'linear-gradient(135deg, var(--acc), var(--acc-2))',
          }}>
            {t('Upload your valid ID →')}
          </Link>
        ) : undefined
      }
    >
      {needsId ? (
        t('You can already file job orders — they’re held pending verification. Upload your valid ID to get verified; once approved, your held orders are sent to KTC automatically.')
      ) : (
        <>
          {t('A KTC admin is verifying your account. You can continue filing job orders, but they’re held until you’re verified. For more information, contact customer service at')}{' '}
          <a href={`mailto:${SUPPORT_EMAIL}`} className="ktc-link">{SUPPORT_EMAIL}</a> ·{' '}
          <a href={`tel:${SUPPORT_PHONE_TEL}`} className="ktc-link">{SUPPORT_PHONE}</a>.
        </>
      )}
      {onRefresh && (
        <>
          {' '}
          <button
            type="button"
            className="ktc-link"
            onClick={onRefresh}
            disabled={refreshCooling}
            title={refreshCooling ? t('Just refreshed — try again in a few seconds') : t('Checks automatically every minute')}
            style={{ fontSize: 13, padding: 0, opacity: refreshCooling ? 0.5 : 1 }}
          >
            {t('↻ Refresh status')}
          </button>
        </>
      )}
    </Notice>
  )
}
