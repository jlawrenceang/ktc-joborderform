import { useEffect, useState } from 'react'
import AdminShell from './AdminShell'
import { supabase } from '../lib/supabase'
import { AdminRow } from './AdminRow'
import { BrokerReview } from './BrokerReview'
import { useFileViewer } from '../components/FileViewerModal'

interface PendingBroker {
  id: string
  customer_code: string | null
  full_name: string | null
  email: string | null
  contact_number: string | null
  customer_id: string | null
  valid_id_path: string | null
  email_confirmed_at: string | null
  terms_version: string | null
  terms_accepted_at: string | null
  privacy_consent_version: string | null
  privacy_consented_at: string | null
}

const REJECT_PRESETS: { status: 'rejected' | 'suspended'; label: string; reason: string }[] = [
  { status: 'rejected', label: 'ID unreadable — ask to re-upload', reason: 'We couldn’t read your valid ID clearly. Please re-upload a clear photo or PDF of a valid government-issued ID.' },
  { status: 'rejected', label: 'Needs updated info — ask to resubmit', reason: 'Please review and update your details, then resubmit so we can complete your verification.' },
  { status: 'suspended', label: 'Suspend account (contact admin)', reason: 'Your account has been suspended. Please contact KTC customer service.' },
]

// Customer rejection: pick one of the three outcomes; rejected = recoverable
// (resubmit), suspended = terminal. Optional note is appended to the reason.
function RejectChoices({ busy, note, onNote, onChoose, onCancel }: {
  busy: boolean; note: string; onNote: (v: string) => void
  onChoose: (status: 'rejected' | 'suspended', reason: string) => void; onCancel: () => void
}) {
  return (
    <div style={{ padding: '12px 14px', borderRadius: 12, background: 'hsl(0 70% 98%)', border: '1px solid hsl(0 60% 88%)', display: 'grid', gap: 8 }}>
      <label className="ktc-label" style={{ fontSize: 12, fontWeight: 600 }}>Choose an outcome (the customer is told why):</label>
      <textarea className="ktc-input" rows={2} value={note} onChange={(e) => onNote(e.target.value)}
        placeholder="Optional note to append (e.g. which field to fix)…" />
      <div style={{ display: 'grid', gap: 6 }}>
        {REJECT_PRESETS.map((p) => (
          <button key={p.label} type="button" disabled={busy}
            onClick={() => onChoose(p.status, p.reason + (note.trim() ? ' — ' + note.trim() : ''))}
            style={{ textAlign: 'left', border: '1px solid hsl(0 60% 85%)', borderRadius: 10, padding: '8px 12px', fontWeight: 600, fontSize: 13, cursor: 'pointer', color: p.status === 'suspended' ? 'hsl(0 65% 40%)' : 'hsl(30 70% 38%)', background: 'rgba(255,255,255,0.8)' }}>
            {p.label}
          </button>
        ))}
        <button type="button" disabled={busy} onClick={onCancel}
          style={{ justifySelf: 'start', border: '1px solid hsl(var(--line))', borderRadius: 10, padding: '8px 12px', fontWeight: 600, fontSize: 13, cursor: 'pointer', background: 'rgba(255,255,255,0.7)', color: 'hsl(var(--ink-2))' }}>
          Cancel
        </button>
      </div>
    </div>
  )
}

export default function Approvals() {
  const [brokers, setBrokers] = useState<PendingBroker[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [acting, setActing] = useState<string | null>(null)
  const [rejectId, setRejectId] = useState<string | null>(null)
  const [rejectReason, setRejectReason] = useState('')
  const [approvedName, setApprovedName] = useState<string | null>(null)

  async function load() {
    const b = await supabase.from('customers').select('id, customer_code, full_name, email, contact_number, customer_id, valid_id_path, email_confirmed_at, terms_version, terms_accepted_at, privacy_consent_version, privacy_consented_at').eq('status', 'pending').order('created_at')
    if (b.error) { setError(b.error.message); setLoading(false); return }
    setBrokers((b.data ?? []) as PendingBroker[])
    setLoading(false)
  }
  useEffect(() => { void load() }, [])

  function resetReject() { setRejectId(null); setRejectReason('') }

  async function decideBroker(id: string, status: 'approved' | 'rejected' | 'suspended', reason?: string, path?: string | null) {
    if (status === 'approved' && !path) {
      return setError('Cannot approve — no valid ID on file yet. Ask the customer to upload one first.')
    }
    const who = brokers.find((r) => r.id === id)
    setActing(id); setError(null)
    // On a final decision (approve/suspend) the ID has been reviewed — delete it
    // (DPA data-minimisation). Only clear valid_id_path if the file actually deleted.
    let clearId = false
    let rmFailed: string | null = null
    if ((status === 'approved' || status === 'suspended') && path) {
      const { error: rmErr } = await supabase.storage.from('valid-ids').remove([path])
      if (!rmErr) clearId = true
      else rmFailed = rmErr.message
    }
    const patch: Record<string, unknown> = {
      status, decided_at: new Date().toISOString(),
      decision_reason: (status === 'rejected' || status === 'suspended') ? (reason?.trim() || null) : null,
    }
    if (clearId) patch.valid_id_path = null
    const { error } = await supabase.from('customers').update(patch).eq('id', id)
    setActing(null)
    if (error) return setError(error.message)
    resetReject()
    setBrokers((x) => x.filter((r) => r.id !== id))
    if (rmFailed) {
      // The decision stands, but DPA deletion didn't happen — tell the admin so
      // the file isn't silently left in storage.
      setError(`Decision saved, but the valid ID could NOT be deleted from storage (${rmFailed}). It is still on file — retry the deletion from the customer's page.`)
    }
    if (status === 'approved') setApprovedName(who?.full_name || who?.email || 'The customer')
  }
  // In-app attachment viewer (modal with Print + Save — no new tabs).
  const { openFromStorage, viewerModal } = useFileViewer(setError)

  return (
    <AdminShell>
      {error && <div className="ktc-glass" style={{ padding: 14, marginBottom: 16, color: 'var(--acc-2)', fontSize: 13 }}>{error}</div>}

      <div className="ktc-glass" style={{ padding: 28, marginBottom: 18 }}>
        <h1 className="ktc-title">Account approvals</h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 20 }}>Review the customer's valid ID and confirm they accepted the Agreement (Terms + Data Privacy consent) before approving.</p>
        {loading ? <span className="ktc-label">Loading…</span> : brokers.length === 0 ? (
          <div className="ktc-label" style={{ fontSize: 14 }}>No accounts pending. 🎉</div>
        ) : (
          <div style={{ display: 'grid', gap: 10 }}>
            {brokers.map((b) => (
              <div key={b.id} style={{ display: 'grid', gap: rejectId === b.id ? 8 : 0 }}>
                <AdminRow title={`${b.customer_code ? b.customer_code + ' · ' : ''}${b.full_name || b.email || 'Unknown'}`}
                  subtitle={`${b.email ?? ''}${b.contact_number ? ` · ${b.contact_number}` : ''}${b.customer_id ? ` · #${b.customer_id}` : ''}`}
                  extra={<BrokerReview b={b} />}
                  onViewId={b.valid_id_path ? () => void openFromStorage('valid-ids', b.valid_id_path, `Valid ID — ${b.full_name || b.email || 'customer'}`) : undefined}
                  canApprove={!!b.valid_id_path}
                  busy={acting === b.id} onApprove={() => decideBroker(b.id, 'approved', undefined, b.valid_id_path)}
                  onReject={() => { setRejectId(b.id); setRejectReason('') }} />
                {rejectId === b.id && (
                  <RejectChoices busy={acting === b.id} note={rejectReason} onNote={setRejectReason}
                    onChoose={(status, reason) => decideBroker(b.id, status, reason, b.valid_id_path)} onCancel={resetReject} />
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {viewerModal}

      {approvedName && (
        <div onClick={() => setApprovedName(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'grid', placeItems: 'center', zIndex: 50, padding: 24 }}>
          <div onClick={(e) => e.stopPropagation()} className="ktc-glass" style={{ maxWidth: 380, width: '100%', padding: 28, textAlign: 'center' }}>
            <div style={{ width: 56, height: 56, margin: '0 auto', borderRadius: 999, display: 'grid', placeItems: 'center', fontSize: 30, color: '#fff', background: 'linear-gradient(135deg, hsl(150 55% 45%), hsl(150 60% 36%))' }}>✓</div>
            <h2 style={{ margin: '14px 0 0', fontSize: 19, fontWeight: 600 }}>Account approved</h2>
            <p className="ktc-label" style={{ marginTop: 8, lineHeight: 1.6, fontSize: 14 }}>
              <b>{approvedName}</b> has been approved and notified by email.
              {error ? ' Note: their valid ID could not be deleted — see the warning on the page.' : ' Their valid ID was removed from storage.'}
            </p>
            <button className="ktc-btn" type="button" onClick={() => setApprovedName(null)} style={{ marginTop: 18, width: '100%' }}>
              Done
            </button>
          </div>
        </div>
      )}
    </AdminShell>
  )
}
