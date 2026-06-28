import { useEffect, useRef, useState, type UIEvent } from 'react'
import { useAuth } from '../lib/AuthContext'
import { supabase } from '../lib/supabase'
import { AGREEMENT_VERSION, AGREEMENT_VERSION_LABEL, AGREEMENT_BODY } from '../content/legal'
import { MarkdownBody } from './MarkdownDoc'
import LangToggle from './LangToggle'
import { useT } from '../lib/i18n'

// Shown by ProtectedRoute when a customer's recorded agreement version no longer matches the
// current AGREEMENT_VERSION (a counsel/material update). has_recorded_consent() only checks the
// version is non-null, so a bump never re-gated — this blocks the portal until the customer
// re-accepts, re-stamping all consent columns server-side via record_agreement_consent. Scoped
// to customers (staff/owner are exempt — they hold no agreement). (T1-07)
export default function ReConsent({ onDone }: { onDone: () => void }) {
  const { t } = useT()
  const { signOut } = useAuth()
  const [agreed, setAgreed] = useState(false)
  const [scrolled, setScrolled] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const agreementRef = useRef<HTMLDivElement>(null)

  // If the agreement is too short to scroll, unlock the tick immediately.
  useEffect(() => {
    const el = agreementRef.current
    if (el && el.scrollHeight <= el.clientHeight + 8) setScrolled(true)
  }, [])

  function onScroll(e: UIEvent<HTMLDivElement>) {
    const el = e.currentTarget
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 8) setScrolled(true)
  }

  async function submit() {
    if (!agreed) { setError(t('Please read and agree to the updated Customer Agreement to continue.')); return }
    setBusy(true); setError(null)
    const { error: rpcErr } = await supabase.rpc('record_agreement_consent', { p_version: AGREEMENT_VERSION })
    setBusy(false)
    if (rpcErr) { setError(rpcErr.message); return }
    onDone()
  }

  return (
    <div style={{ display: 'grid', placeItems: 'center', minHeight: '100%', padding: 24 }}>
      <div className="ktc-glass ktc-rise" style={{ width: '100%', maxWidth: 520, padding: '32px 32px 28px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 48 }} />
          <LangToggle />
        </div>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 650, letterSpacing: '-0.01em' }}>{t('Our Customer Agreement has been updated')}</h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 20, fontSize: 13.5, lineHeight: 1.55 }}>
          {t('We’ve updated the KTC Customer Agreement ({version}). Please review and accept it to keep using the portal.', { version: AGREEMENT_VERSION_LABEL })}
        </p>

        {error && (
          <div role="alert" style={{ marginBottom: 14, fontSize: 13, fontWeight: 500, color: 'var(--acc-2)', padding: '10px 13px', borderRadius: 10, background: 'var(--c-h0-75-97)', border: '1px solid var(--c-h0-70-88)' }}>
            {error}
          </div>
        )}

        <div style={{ display: 'grid', gap: 10 }}>
          <span className="ktc-label" style={{ fontSize: 12, fontWeight: 600 }}>
            {t('KTC Customer Agreement ({version})', { version: AGREEMENT_VERSION_LABEL })}
          </span>
          <div style={{
            fontSize: 12, fontWeight: 600, padding: '8px 12px', borderRadius: 8,
            background: scrolled ? 'var(--c-h150-50-94)' : 'var(--c-h40-95-90)',
            color: scrolled ? 'var(--c-h150-55-28)' : 'var(--c-h30-80-34)',
            border: `1px solid ${scrolled ? 'var(--c-h150-45-78)' : 'var(--c-h40-85-75)'}`,
          }}>
            {scrolled
              ? t('✓ Thanks for reading — you can now check the consent box below.')
              : t('↓ Please scroll to the end of the agreement to enable the consent checkbox.')}
          </div>
          <div ref={agreementRef} onScroll={onScroll} style={{ maxHeight: 260, overflowY: 'auto', borderRadius: 12, border: '1px solid var(--glass-brd)', background: 'var(--c-w50)', padding: '12px 16px', fontSize: 12 }}>
            <MarkdownBody body={AGREEMENT_BODY} />
          </div>
          <label style={{ display: 'flex', gap: 9, alignItems: 'flex-start', fontSize: 13, lineHeight: 1.5, opacity: scrolled ? 1 : 0.5 }}>
            <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} disabled={!scrolled} style={{ marginTop: 2, flex: '0 0 auto' }} required />
            <span className="ktc-label" style={{ fontSize: 13 }}>
              {t('I have read and accept the updated')} <b>{t('KTC Customer Agreement')}</b> {t('— including the Terms & Conditions, and my consent to KTC processing my personal data.')}
            </span>
          </label>
        </div>

        <button className="ktc-btn" type="button" disabled={busy || !agreed} onClick={() => void submit()} style={{ width: '100%', marginTop: 18 }}>
          {busy ? t('Please wait…') : t('Accept and continue')}
        </button>
        <p style={{ marginTop: 12, textAlign: 'center' }}>
          <button type="button" className="ktc-link" style={{ fontSize: 12.5 }} onClick={() => void signOut()}>{t('Sign out')}</button>
        </p>
      </div>
    </div>
  )
}
