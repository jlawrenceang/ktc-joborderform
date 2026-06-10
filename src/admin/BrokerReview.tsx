import type { CSSProperties } from 'react'

// The fields BrokerReview needs — satisfied by both the Approvals query row and
// the full Broker type.
export interface ReviewBroker {
  status?: string
  valid_id_path: string | null
  email_confirmed_at: string | null
  terms_version: string | null
  terms_accepted_at: string | null
  privacy_consent_version: string | null
  privacy_consented_at: string | null
}

function fmtDate(s: string | null): string | null {
  if (!s) return null
  const d = new Date(s)
  return isNaN(d.getTime()) ? null : d.toLocaleDateString()
}

const pill = (bg: string, fg: string): CSSProperties => ({
  fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 999, background: bg, color: fg,
})

// Email-confirmed + valid-ID + Terms / Data-Privacy consent badges. Green ✓ when
// present, amber ⚠ when missing. An approved customer's ID is deleted after review
// (DPA), so we show "✓ ID verified" rather than a "no ID" warning.
export function BrokerReview({ b }: { b: ReviewBroker }) {
  const ok = pill('hsl(150 50% 93%)', 'hsl(150 60% 30%)')
  const warn = pill('hsl(0 70% 95%)', 'hsl(0 65% 45%)')
  const terms = fmtDate(b.terms_accepted_at)
  const dpa = fmtDate(b.privacy_consented_at)
  const confirmed = fmtDate(b.email_confirmed_at)
  const idVerified = !b.valid_id_path && b.status === 'approved'
  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
      <span style={confirmed ? ok : warn}>{confirmed ? `✓ Email confirmed ${confirmed}` : '⚠ Email not confirmed'}</span>
      <span style={b.valid_id_path || idVerified ? ok : warn}>
        {b.valid_id_path ? '✓ Valid ID on file' : idVerified ? '✓ ID verified' : '⚠ No valid ID'}
      </span>
      <span style={terms || dpa ? ok : warn}>{(terms || dpa) ? `✓ Terms & DPA ${terms || dpa}` : '⚠ Agreement not accepted'}</span>
    </div>
  )
}
