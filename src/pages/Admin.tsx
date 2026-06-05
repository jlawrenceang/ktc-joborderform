import { useEffect, useState } from 'react'
import Shell from '../components/Shell'
import { supabase } from '../lib/supabase'
import { useBroker } from '../lib/useBroker'

interface PendingRow {
  id: string
  requested_at: string
  broker: { full_name: string | null; email: string | null; customer_id: string | null; valid_id_path: string | null } | null
  consignee: { code: string; name: string } | null
}

// Supabase types embedded to-one relations as arrays; normalize to an object.
function one<T>(v: T | T[] | null | undefined): T | null {
  if (Array.isArray(v)) return v[0] ?? null
  return v ?? null
}

export default function Admin() {
  const { broker, loading: brokerLoading } = useBroker()
  const [rows, setRows] = useState<PendingRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [acting, setActing] = useState<string | null>(null)

  async function load() {
    const { data, error } = await supabase
      .from('accreditations')
      .select(
        'id, requested_at, broker:brokers(full_name, email, customer_id, valid_id_path), consignee:consignees(code, name)',
      )
      .eq('status', 'pending')
      .order('requested_at', { ascending: true })
    if (error) {
      setError(error.message)
      setLoading(false)
      return
    }
    const normalized = ((data ?? []) as unknown as PendingRow[]).map((r) => ({
      ...r,
      broker: one(r.broker),
      consignee: one(r.consignee),
    }))
    setRows(normalized)
    setLoading(false)
  }

  useEffect(() => {
    void load()
  }, [])

  async function decide(id: string, status: 'approved' | 'rejected') {
    setActing(id)
    setError(null)
    const { error } = await supabase
      .from('accreditations')
      .update({ status, decided_at: new Date().toISOString() })
      .eq('id', id)
    setActing(null)
    if (error) {
      setError(error.message)
      return
    }
    setRows((rs) => rs.filter((r) => r.id !== id))
  }

  async function viewId(path: string | null | undefined) {
    if (!path) return
    const { data, error } = await supabase.storage.from('valid-ids').createSignedUrl(path, 60)
    if (error || !data) {
      setError(error?.message ?? 'Could not open ID.')
      return
    }
    window.open(data.signedUrl, '_blank', 'noopener')
  }

  if (!brokerLoading && !broker?.is_admin) {
    return (
      <Shell>
        <div className="ktc-glass" style={{ padding: 28 }}>
          <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600 }}>Admin</h1>
          <p className="ktc-label" style={{ marginTop: 8 }}>You don't have admin access.</p>
        </div>
      </Shell>
    )
  }

  return (
    <Shell>
      <div className="ktc-glass" style={{ padding: 28 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>
          Accreditation approvals
        </h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 22 }}>
          Pending broker → consignee requests. Approving makes the consignee selectable in that broker's Job Order form.
        </p>

        {error && <div style={{ color: 'var(--acc-2)', fontSize: 13, marginBottom: 12 }}>{error}</div>}

        {loading ? (
          <span className="ktc-label">Loading…</span>
        ) : rows.length === 0 ? (
          <div className="ktc-label" style={{ fontSize: 14 }}>No pending requests. 🎉</div>
        ) : (
          <div style={{ display: 'grid', gap: 10 }}>
            {rows.map((r) => (
              <div
                key={r.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                  padding: '12px 14px',
                  borderRadius: 12,
                  background: 'rgba(255,255,255,0.55)',
                  border: '1px solid var(--glass-brd)',
                }}
              >
                <div style={{ fontSize: 14, lineHeight: 1.5 }}>
                  <div>
                    <b>{r.broker?.full_name || r.broker?.email || 'Unknown broker'}</b>
                    {r.broker?.customer_id ? ` · #${r.broker.customer_id}` : ''}
                  </div>
                  <div className="ktc-label" style={{ fontSize: 13 }}>
                    requests <b>{r.consignee ? `${r.consignee.code} – ${r.consignee.name}` : 'consignee'}</b>
                  </div>
                  {r.broker?.valid_id_path && (
                    <button className="ktc-link" style={{ fontSize: 12, marginTop: 2 }}
                      onClick={() => viewId(r.broker?.valid_id_path)}>
                      View valid ID
                    </button>
                  )}
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    type="button"
                    onClick={() => decide(r.id, 'approved')}
                    disabled={acting === r.id}
                    style={{
                      border: 0, borderRadius: 10, padding: '8px 14px', fontWeight: 600, fontSize: 13,
                      cursor: 'pointer', color: '#fff',
                      background: 'linear-gradient(135deg, hsl(150 55% 42%), hsl(150 60% 34%))',
                    }}
                  >
                    Approve
                  </button>
                  <button
                    type="button"
                    onClick={() => decide(r.id, 'rejected')}
                    disabled={acting === r.id}
                    style={{
                      border: '1px solid hsl(var(--line))', borderRadius: 10, padding: '8px 14px',
                      fontWeight: 600, fontSize: 13, cursor: 'pointer',
                      background: 'rgba(255,255,255,0.7)', color: 'hsl(var(--ink-2))',
                    }}
                  >
                    Reject
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Shell>
  )
}
