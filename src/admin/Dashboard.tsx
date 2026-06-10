import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import AdminShell from './AdminShell'
import { supabase } from '../lib/supabase'

async function count(table: string, filter?: { col: string; val: string }) {
  let q = supabase.from(table).select('id', { count: 'exact', head: true })
  if (filter) q = q.eq(filter.col, filter.val)
  const { count } = await q
  return count ?? 0
}

interface Stats {
  pendingAccounts: number
  pendingAccreditations: number
  pendingConsignees: number
  brokers: number
  consignees: number
  jobOrders: number
}

const ip = { width: 22, height: 22, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
const ApprovalsIcon = () => (<svg {...ip}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="m16 11 2 2 4-4" /></svg>)
const AccreditationIcon = () => (<svg {...ip}><circle cx="12" cy="8" r="6" /><path d="M15.477 12.89 17 22l-5-3-5 3 1.523-9.11" /></svg>)
const InboxIcon = () => (<svg {...ip}><path d="M22 12h-6l-2 3h-4l-2-3H2" /><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" /></svg>)
const CustomersIcon = () => (<svg {...ip}><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></svg>)
const ConsigneesIcon = () => (<svg {...ip}><path d="M3 21h18M5 21V7l8-4v18M19 21V11l-6-4" /><path d="M9 9v.01M9 12v.01M9 15v.01M9 18v.01" /></svg>)
const JobOrdersIcon = () => (<svg {...ip}><path d="M14 3v4a1 1 0 0 0 1 1h4" /><path d="M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2z" /><path d="M9 13h6M9 17h6" /></svg>)

const cards: { key: keyof Stats; label: string; to: string; icon: ReactNode; accent?: boolean }[] = [
  { key: 'pendingAccounts', label: 'Accounts awaiting approval', to: '/admin/approvals', icon: <ApprovalsIcon />, accent: true },
  { key: 'pendingAccreditations', label: 'Accreditations pending', to: '/admin/approvals', icon: <AccreditationIcon />, accent: true },
  { key: 'pendingConsignees', label: 'Consignees pending', to: '/admin/consignees', icon: <InboxIcon />, accent: true },
  { key: 'brokers', label: 'Customers', to: '/admin/customers', icon: <CustomersIcon /> },
  { key: 'consignees', label: 'Consignees', to: '/admin/consignees', icon: <ConsigneesIcon /> },
  { key: 'jobOrders', label: 'Job orders', to: '/admin/job-orders', icon: <JobOrdersIcon /> },
]

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null)

  useEffect(() => {
    Promise.all([
      count('customers', { col: 'status', val: 'pending' }),
      count('accreditations', { col: 'status', val: 'pending' }),
      count('consignees', { col: 'status', val: 'pending' }),
      count('customers'),
      count('consignees'),
      count('job_orders'),
    ]).then(([pendingAccounts, pendingAccreditations, pendingConsignees, brokers, consignees, jobOrders]) =>
      setStats({ pendingAccounts, pendingAccreditations, pendingConsignees, brokers, consignees, jobOrders }),
    )
  }, [])

  return (
    <AdminShell>
      <div className="ktc-glass" style={{ padding: 28, marginBottom: 18 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>Dashboard</h1>
        <p className="ktc-label" style={{ marginTop: 6 }}>Overview of the KTC Online Portal.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', gap: 16 }}>
        {cards.map((c) => {
          const val = stats ? stats[c.key] : null
          const active = !!c.accent && (val ?? 0) > 0 // pending tile with work waiting
          return (
            <Link
              key={c.key}
              to={c.to}
              className="ktc-glass"
              style={{
                position: 'relative',
                aspectRatio: '1 / 1',
                display: 'flex',
                flexDirection: 'column',
                padding: 18,
                borderRadius: 22,
                textDecoration: 'none',
                color: 'inherit',
                border: active ? '1px solid rgb(var(--acc-rgb) / 0.45)' : undefined,
                boxShadow: active ? '0 8px 28px rgb(var(--acc-rgb) / 0.16)' : undefined,
                transition: 'transform 0.18s ease, box-shadow 0.18s ease',
              }}
            >
              <span
                style={{
                  width: 44, height: 44, borderRadius: 14, display: 'grid', placeItems: 'center',
                  background: active
                    ? 'linear-gradient(135deg, rgb(var(--acc-rgb) / 0.22), rgb(var(--acc-rgb) / 0.10))'
                    : 'rgba(255,255,255,0.55)',
                  border: '1px solid var(--glass-brd)',
                  color: c.accent ? 'var(--acc)' : 'hsl(var(--ink-2))',
                }}
              >
                {c.icon}
              </span>

              {active && (
                <span style={{ position: 'absolute', top: 16, right: 16, width: 9, height: 9, borderRadius: 999, background: 'var(--acc)', boxShadow: '0 0 0 4px rgb(var(--acc-rgb) / 0.18)' }} />
              )}

              <div style={{ marginTop: 'auto' }}>
                <div style={{ fontSize: 34, fontWeight: 600, letterSpacing: '-0.03em', lineHeight: 1, color: active ? 'var(--acc)' : 'hsl(var(--ink))' }}>
                  {val ?? '—'}
                </div>
                <div className="ktc-label" style={{ fontSize: 12.5, marginTop: 8, lineHeight: 1.35 }}>{c.label}</div>
              </div>
            </Link>
          )
        })}
      </div>
    </AdminShell>
  )
}
