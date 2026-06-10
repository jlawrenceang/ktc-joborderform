import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Shell from '../components/Shell'
import { supabase } from '../lib/supabase'
import type { JobOrder } from '../lib/types'

const STATUS_LABEL: Record<string, string> = {
  held: 'Pending approval',
  submitted: 'Submitted',
  processing: 'Approved · processing',
  on_hold: 'On hold · info needed',
  completed: 'Completed',
  rejected: 'Rejected',
  cancelled: 'Cancelled',
}

// Per-status pill colours, drawn from the same palette as the shared Notice tones.
const STATUS_STYLE: Record<string, { bg: string; ink: string }> = {
  held: { bg: 'hsl(40 90% 86%)', ink: 'hsl(30 75% 32%)' },
  submitted: { bg: 'hsl(210 60% 90%)', ink: 'hsl(210 55% 36%)' },
  processing: { bg: 'hsl(265 55% 91%)', ink: 'hsl(265 45% 42%)' },
  on_hold: { bg: 'hsl(40 90% 86%)', ink: 'hsl(30 75% 32%)' },
  completed: { bg: 'hsl(150 50% 88%)', ink: 'hsl(150 55% 26%)' },
  rejected: { bg: 'hsl(0 75% 92%)', ink: 'hsl(0 65% 42%)' },
  cancelled: { bg: 'hsl(220 12% 88%)', ink: 'hsl(220 8% 40%)' },
}

function StatusBadge({ status }: { status: string }) {
  const s = STATUS_STYLE[status] ?? STATUS_STYLE.cancelled
  return (
    <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 10px', borderRadius: 999, background: s.bg, color: s.ink, letterSpacing: '0.02em', whiteSpace: 'nowrap' }}>
      {STATUS_LABEL[status] ?? status}
    </span>
  )
}

export default function MyJobOrders() {
  const [orders, setOrders] = useState<JobOrder[]>([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState<Set<string>>(new Set())

  function toggle(id: string) {
    setOpen((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  useEffect(() => {
    supabase
      .from('job_orders')
      .select(
        'id, jo_number, entry_number, status, admin_note, created_at, consignee:consignees(code, name), lines:job_order_lines(container_number, service_request)',
      )
      .order('created_at', { ascending: false })
      .then(({ data }) => {
        const rows = (data ?? []) as unknown as JobOrder[]
        setOrders(rows)
        setLoading(false)
        // Auto-expand the order just filed (handed over from the New Job Order page).
        const filedId = sessionStorage.getItem('ktc_jo_filed_id')
        if (filedId) {
          sessionStorage.removeItem('ktc_jo_filed_id')
          if (rows.some((o) => o.id === filedId)) setOpen(new Set([filedId]))
        }
      })
  }, [])

  return (
    <Shell>
      <div className="ktc-glass" style={{ padding: 28 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 16, flexWrap: 'wrap' }}>
          <div>
            <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>My Job Orders</h1>
            <p className="ktc-label" style={{ marginTop: 6, marginBottom: 0 }}>
              Tap an order to see its containers and services.
            </p>
          </div>
          <Link to="/job-order" className="ktc-btn" style={{ width: 'auto', padding: '9px 16px', fontSize: 13, textDecoration: 'none', whiteSpace: 'nowrap' }}>
            + New Job Order
          </Link>
        </div>

        <div style={{ marginTop: 22 }}>
          {loading ? (
            <span className="ktc-label">Loading…</span>
          ) : orders.length === 0 ? (
            <div className="ktc-label" style={{ fontSize: 14 }}>
              No job orders yet. Create one on the{' '}
              <Link to="/job-order" className="ktc-link">New Job Order</Link> page.
            </div>
          ) : (
            <div style={{ display: 'grid', gap: 12 }}>
              {orders.map((o) => {
                const isOpen = open.has(o.id)
                const count = o.lines?.length ?? 0
                return (
                  <div
                    key={o.id}
                    style={{ borderRadius: 14, background: 'rgba(255,255,255,0.55)', border: '1px solid var(--glass-brd)', overflow: 'hidden' }}
                  >
                    <button
                      type="button"
                      onClick={() => toggle(o.id)}
                      aria-expanded={isOpen}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left',
                        padding: '14px 16px', border: 0, background: 'transparent', cursor: 'pointer',
                      }}
                    >
                      <span
                        aria-hidden
                        style={{ flex: '0 0 auto', fontSize: 13, color: 'hsl(var(--ink-3))', transition: 'transform 0.18s ease', transform: isOpen ? 'rotate(90deg)' : 'none' }}
                      >
                        ▶
                      </span>
                      <span style={{ minWidth: 0, flex: '1 1 auto' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                          <b style={{ fontSize: 15 }}>{o.jo_number ?? 'Draft (no number yet)'}</b>
                          <StatusBadge status={o.status} />
                        </span>
                        <span className="ktc-label" style={{ display: 'block', fontSize: 12.5, marginTop: 4 }}>
                          {o.consignee ? `${o.consignee.code} – ${o.consignee.name}` : 'No consignee'}
                          {o.entry_number ? ` · Entry ${o.entry_number}` : ''}
                        </span>
                      </span>
                      <span className="ktc-label" style={{ flex: '0 0 auto', fontSize: 12, textAlign: 'right', whiteSpace: 'nowrap' }}>
                        {count} container{count === 1 ? '' : 's'}
                        <span style={{ display: 'block', opacity: 0.7 }}>{new Date(o.created_at).toLocaleDateString()}</span>
                      </span>
                    </button>

                    {isOpen && (
                      <div style={{ padding: '0 16px 16px 40px' }}>
                        {o.status === 'held' && (
                          <div style={{ fontSize: 12, color: 'hsl(30 60% 38%)', marginBottom: 12, lineHeight: 1.5 }}>
                            Can’t be processed until you pass final verification — upload your valid ID, then a KTC admin verifies your account and it’s sent automatically.
                          </div>
                        )}
                        {o.status === 'on_hold' && o.admin_note && (
                          <div style={{ fontSize: 12.5, marginBottom: 12, lineHeight: 1.5, padding: '9px 12px', borderRadius: 9, background: 'hsl(40 90% 96%)', border: '1px solid hsl(35 85% 84%)', color: 'hsl(30 60% 32%)' }}>
                            <b>Information needed:</b> {o.admin_note}
                          </div>
                        )}
                        {o.status === 'rejected' && o.admin_note && (
                          <div style={{ fontSize: 12.5, marginBottom: 12, lineHeight: 1.5, padding: '9px 12px', borderRadius: 9, background: 'hsl(0 75% 97%)', border: '1px solid hsl(0 70% 88%)', color: 'hsl(0 60% 40%)' }}>
                            <b>Rejected:</b> {o.admin_note}
                          </div>
                        )}
                        {(o.status === 'processing' || o.status === 'completed') && (
                          <Link to={`/job-order/${o.id}/print`} target="_blank" style={{ display: 'inline-block', marginBottom: 12, padding: '7px 14px', borderRadius: 9, fontSize: 12.5, fontWeight: 600, textDecoration: 'none', color: '#fff', background: 'linear-gradient(135deg, var(--acc), var(--acc-2))' }}>
                            Print slip ↗
                          </Link>
                        )}
                        {count === 0 ? (
                          <div className="ktc-label" style={{ fontSize: 13 }}>No containers on this order.</div>
                        ) : (
                          <div style={{ display: 'grid', gap: 6 }}>
                            {o.lines!.map((l, i) => (
                              <div
                                key={i}
                                style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12, fontSize: 13, padding: '8px 12px', borderRadius: 9, background: 'rgba(255,255,255,0.55)', border: '1px solid var(--glass-brd)' }}
                              >
                                <span style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontWeight: 600 }}>{l.container_number}</span>
                                <span className="ktc-label" style={{ fontSize: 12.5 }}>{l.service_request}</span>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </Shell>
  )
}
