import { useEffect, useState, type CSSProperties } from 'react'
import { supabase } from '../lib/supabase'
import { useT } from '../lib/i18n'

// "Need help?" contact line for the PUBLIC pages (Landing, Login). Reads the
// real KTC support phone + email from public.support_contact — which a
// logged-out (anon) visitor can read thanks to the public SELECT policy added
// in migration 0160. Renders nothing until at least one of phone/email is
// configured, so an empty contact table leaves no dangling label.
export default function NeedHelp({
  align = 'left',
  style,
}: {
  align?: 'left' | 'center'
  style?: CSSProperties
}) {
  const { t } = useT()
  const [phone, setPhone] = useState('')
  const [email, setEmail] = useState('')

  useEffect(() => {
    let alive = true
    // .then (not a bare builder) so the lazy query actually fires.
    void supabase
      .from('support_contact')
      .select('key, value')
      .in('key', ['phone', 'email'])
      .then(({ data }) => {
        if (!alive) return
        for (const row of (data ?? []) as { key: string; value: string | null }[]) {
          const v = (row.value ?? '').trim()
          if (!v) continue
          if (row.key === 'phone') setPhone(v)
          else if (row.key === 'email') setEmail(v)
        }
      })
    return () => { alive = false }
  }, [])

  if (!phone && !email) return null

  return (
    <div style={{ textAlign: align, ...style }}>
      <span
        style={{
          display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
          justifyContent: 'center', padding: '6px 14px', borderRadius: 999,
          border: '1px solid var(--glass-brd)', background: 'var(--c-w55)',
          fontSize: 12, lineHeight: 1.4,
        }}
      >
        <span className="ktc-label" style={{ fontWeight: 600 }}>{t('Need help?')}</span>
        {phone && (
          <a className="ktc-link" href={`tel:${phone.replace(/[^+0-9]/g, '')}`}>{t('Call')} {phone}</a>
        )}
        {phone && email && <span style={{ opacity: 0.4 }}>·</span>}
        {email && (
          <a className="ktc-link" href={`mailto:${email}`}>{t('Email us')}</a>
        )}
      </span>
    </div>
  )
}
