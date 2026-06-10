import type { ReactNode } from 'react'
import { Link, NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useBroker } from '../lib/useBroker'

// Persistent frosted admin nav — every admin surface one tap away; the active
// pill shows where you are (replaces the old back-button + breadcrumb).
const NAV = [
  { to: '/admin', label: 'Dashboard', end: true },
  { to: '/admin/approvals', label: 'Approvals' },
  { to: '/admin/customers', label: 'Customers' },
  { to: '/admin/consignees', label: 'Consignees' },
  { to: '/admin/job-orders', label: 'Job Orders' },
  { to: '/admin/settings', label: 'Settings' },
]

export default function AdminShell({ children }: { children: ReactNode; crumb?: string }) {
  const { signOut } = useAuth()
  const { broker } = useBroker()
  const navigate = useNavigate()

  async function handleSignOut() {
    await signOut()
    navigate('/login', { replace: true })
  }

  const role = broker?.is_owner ? 'Owner' : broker?.is_admin ? 'Admin' : ''

  return (
    <div style={{ maxWidth: 1020, margin: '0 auto', padding: '14px 20px 60px' }}>
      <nav className="ktc-nav" aria-label="Admin">
        <Link to="/admin" aria-label="Go to Dashboard" style={{ display: 'inline-flex', flex: '0 0 auto', padding: '0 6px' }}>
          <img src="/ktc-logo.png" alt="KTC" style={{ height: 34 }} />
        </Link>
        <span
          title={role ? `${role}: ${broker?.email ?? ''}` : undefined}
          style={{
            flex: '0 0 auto', fontSize: 10.5, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase',
            padding: '4px 9px', borderRadius: 999, color: '#fff', marginRight: 4,
            background: 'linear-gradient(135deg, var(--acc), var(--acc-2))',
          }}
        >
          {role || 'Admin'}
        </span>
        <div className="ktc-nav-links">
          {NAV.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end={n.end}
              className={({ isActive }) => `ktc-nav-link${isActive ? ' is-active' : ''}`}
            >
              {n.label}
            </NavLink>
          ))}
        </div>
        <button className="ktc-nav-link" onClick={handleSignOut} style={{ flex: '0 0 auto' }}>
          Sign out
        </button>
      </nav>

      <div className="ktc-stagger">{children}</div>
    </div>
  )
}
