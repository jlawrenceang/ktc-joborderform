import type { ReactNode } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/AuthContext'
import { useBroker } from '../lib/useBroker'
import { hasAdminAccess } from '../lib/types'
import { useIdleLogout } from '../lib/useIdleLogout'
import PendingPanel from './PendingPanel'
import BrokerStatusBanner from './BrokerStatusBanner'

const IDLE_LOGOUT_MS = 10 * 60 * 1000 // auto sign-out after 10 min of inactivity

const baseLinks = [
  { to: '/', label: 'Home', end: true },
  { to: '/job-order', label: 'New Job Order' },
  { to: '/job-orders', label: 'My Job Orders' },
  { to: '/agreement', label: 'Agreement' },
]

export default function Shell({ children }: { children: ReactNode }) {
  const { signOut } = useAuth()
  const { broker } = useBroker()
  const navigate = useNavigate()
  const links = baseLinks

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
          <nav style={{ display: 'flex', gap: 8, marginBottom: 22, flexWrap: 'wrap' }}>
            {links.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.end}
                style={({ isActive }) => ({
                  padding: '7px 14px',
                  borderRadius: 999,
                  fontSize: 13,
                  fontWeight: 500,
                  textDecoration: 'none',
                  color: isActive ? '#fff' : 'hsl(var(--ink-2))',
                  background: isActive ? 'linear-gradient(135deg, var(--acc), var(--acc-2))' : 'rgba(255,255,255,0.6)',
                  border: '1px solid var(--glass-brd)',
                })}
              >
                {l.label}
              </NavLink>
            ))}
          </nav>
          {children}
        </>
      )}
    </div>
  )
}
