import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Shell from '../components/Shell'
import { supabase } from '../lib/supabase'
import { useAutoRefresh } from '../lib/useAutoRefresh'
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

// Per-status semantic tone, rendered with the shared .ktc-chip classes.
const STATUS_TONE: Record<string, string> = {
  held: 'warning',
  submitted: 'info',
  processing: 'progress',
  on_hold: 'warning',
  completed: 'success',
  rejected: 'danger',
  cancelled: '',
}

function StatusBadge({ status }: { status: string }) {
  const tone = STATUS_TONE[status]
  return (
    <span className={tone ? `ktc-chip ktc-chip--${tone}` : 'ktc-chip'}>
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

  async function load() {
    const { data } = await supabase
      .from('job_orders')
      .select(
        'id, jo_number, entry_number, status, admin_note, created_at, consignee:consignees(code, name), lines:job_order_lines(container_number, service_request)',
      )
      .order('created_at', { ascending: false })
    const rows = (data ?? []) as unknown as JobOrder[]
    setOrders(rows)
    setLoading(false)
    // Auto-expand the order just filed (handed over from the New Job Order page).
    const filedId = sessionStorage.getItem('ktc_jo_filed_id')
    if (filedId) {
      sessionStorage.removeItem('ktc_jo_filed_id')
      if (rows.some((o) => o.id === filedId)) setOpen(new Set([filedId]))
    }
  }

  useEffect(() => { void load() }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Statuses auto-refresh every 60s while the tab is visible; the manual
  // button is rate-limited to one pull per 10s.
  const { refresh, cooling } = useAutoRefresh(load)

  return (
    <Shell>
      <div className="ktc-glass" style={{ padding: 28 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 16, flexWrap: 'wrap' }}>
          <div>
            <h1 className="ktc-title">My Job Orders</h1>
            <p className="ktc-sub" style={{ marginBottom: 0 }}>
              Tap an order to see its containers and services.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <button type="button" className="ktc-btn-secondary ktc-btn--sm" onClick={refresh} disabled={cooling} title={cooling ? 'Just refreshed — try again in a few seconds' : 'Refresh statuses (auto-refreshes every minute)'}>
              ↻ Refresh
            </button>
            <Link to="/job-order" className="ktc-btn" style={{ width: 'auto', padding: '9px 16px', fontSize: 13, textDecoration: 'none', whiteSpace: 'nowrap' }}>
              + New Job Order
            </Link>
          </div>
        </div>

        <div style={{ marginTop: 22 }}>
          {loading ? (
            <div style={{ display: 'grid', gap: 12 }} aria-label="Loading job orders">
              {[64, 64, 64].map((h, i) => (
                <div key={i} className="ktc-skeleton" style={{ height: h, borderRadius: 14 }} />
              ))}
            </div>
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
                          <b className={o.jo_number ? 'ktc-mono' : undefined} style={{ fontSize: o.jo_number ? 14.5 : 14 }}>{o.jo_number ?? 'Draft (no number yet)'}</b>
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
                          <Link to={`/job-order/${o.id}/print`} target="_blank" className="ktc-btn ktc-btn--sm" style={{ display: 'inline-flex', marginBottom: 12, textDecoration: 'none' }}>
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
                                <span className="ktc-mono" style={{ fontWeight: 600 }}>{l.container_number}</span>
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
