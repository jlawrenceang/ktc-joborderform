import type { ReactNode } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useBroker } from '../lib/useBroker'
import { hasAdminAccess } from '../lib/types'
import { useIdleLogout } from '../lib/useIdleLogout'
import { APP_VERSION } from '../version'
import PendingPanel from './PendingPanel'
import BrokerStatusBanner from './BrokerStatusBanner'

const IDLE_LOGOUT_MS = 10 * 60 * 1000 // auto sign-out after 10 min of inactivity

// Path → breadcrumb label. The Home cards are the primary navigation.
const CRUMBS: Record<string, string> = {
  '/': 'Home',
  '/job-order': 'New Job Order',
  '/job-orders': 'My Job Orders',
  '/accreditation': 'Accreditation',
}

export default function Shell({ children }: { children: ReactNode }) {
  const { signOut } = useAuth()
  const { broker } = useBroker()
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const isHome = pathname === '/'
  const current = CRUMBS[pathname] ?? ''

  // Locked out entirely: rejected / suspended (non-admin) brokers get a message only.
  const locked = !!broker && !hasAdminAccess(broker) && (broker.status === 'rejected' || broker.status === 'suspended')
  // Pending (confirmed) brokers get the full portal + a status banner; submit is
  // gated server-side (job_orders insert requires broker_is_approved()).
  const pending = !!broker && !hasAdminAccess(broker) && broker.status === 'pending'

  async function handleSignOut() {
    await signOut()
    navigate('/login', { replace: true })
  }

  // Idle timeout: sign brokers out after 10 minutes of inactivity.
  useIdleLogout(() => {
    sessionStorage.setItem('ktc_idle_logout', '1')
    void handleSignOut()
  }, IDLE_LOGOUT_MS)

  return (
    <div style={{ maxWidth: 860, margin: '0 auto', padding: '28px 24px 60px' }}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 48 }} />
        <button className="ktc-link" onClick={handleSignOut}>Sign out</button>
      </header>

      {locked ? (
        <PendingPanel broker={broker!} />
      ) : (
        <>
          {pending && <BrokerStatusBanner broker={broker!} />}
          <nav aria-label="Breadcrumb" style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 22, fontSize: 14 }}>
            {isHome ? (
              <span style={{ fontWeight: 600 }}>Home</span>
            ) : (
              <>
                <Link to="/" className="ktc-link">Home</Link>
                <span style={{ color: 'hsl(var(--ink-2))', opacity: 0.5 }}>›</span>
                <span style={{ fontWeight: 600 }}>{current}</span>
              </>
            )}
          </nav>
          {children}
        </>
      )}

      <footer style={{ marginTop: 44, paddingTop: 18, borderTop: '1px solid var(--glass-brd)', textAlign: 'center', fontSize: 12, color: 'hsl(var(--ink-2))' }}>
        <Link to="/agreement" className="ktc-link" style={{ fontSize: 12 }}>Customer Agreement (Terms &amp; Conditions)</Link>
        <div style={{ marginTop: 6, opacity: 0.75 }}>
          KTC Online Portal {APP_VERSION} · © {new Date().getFullYear()} KTC Container Terminal Corp.
        </div>
      </footer>
    </div>
  )
}
