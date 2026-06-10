import { Link } from 'react-router-dom'
import type { ReactNode } from 'react'
import Shell from '../components/Shell'
import { useAuth } from '../lib/AuthContext'
import { useBroker } from '../lib/useBroker'

const iconProps = { width: 20, height: 20, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }

const NewOrderIcon = () => (
  <svg {...iconProps}><path d="M14 3v4a1 1 0 0 0 1 1h4" /><path d="M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2z" /><path d="M12 11v6M9 14h6" /></svg>
)
const OrdersIcon = () => (
  <svg {...iconProps}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" /></svg>
)

const cards: { to: string; title: string; desc: string; icon: ReactNode }[] = [
  { to: '/job-order', title: 'New Job Order', desc: 'X-ray / DEA / OOG stripping requests', icon: <NewOrderIcon /> },
  { to: '/job-orders', title: 'My Job Orders', desc: 'Track your filed orders', icon: <OrdersIcon /> },
]

export default function Home() {
  const { session } = useAuth()
  const { broker } = useBroker()
  const name = broker?.full_name || session?.user.email

  return (
    <Shell>
      <div style={{ marginBottom: 22 }}>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 600, letterSpacing: '-0.02em' }}>
          Welcome{name ? `, ${name}` : ''}
        </h1>
        <p className="ktc-label" style={{ marginTop: 6, fontSize: 14 }}>
          KTC Online Portal — file job orders for terminal services and track their status.
          {broker?.customer_code && (
            <>
              {' · '}<span style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontWeight: 600 }}>{broker.customer_code}</span>
            </>
          )}
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 12 }}>
        {cards.map((c) => (
          <Link
            key={c.to}
            to={c.to}
            className="ktc-glass"
            style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', borderRadius: 14, textDecoration: 'none', color: 'inherit' }}
          >
            <span style={{ flex: '0 0 auto', width: 42, height: 42, borderRadius: 12, display: 'grid', placeItems: 'center', background: 'linear-gradient(135deg, rgb(var(--acc-rgb) / 0.16), rgb(var(--acc-rgb) / 0.08))', color: 'var(--acc)' }}>
              {c.icon}
            </span>
            <span style={{ minWidth: 0 }}>
              <span style={{ display: 'block', fontSize: 15, fontWeight: 600 }}>{c.title}</span>
              <span className="ktc-label" style={{ fontSize: 12.5 }}>{c.desc}</span>
            </span>
            <span style={{ marginLeft: 'auto', color: 'hsl(var(--ink-3))', fontSize: 20, lineHeight: 1 }}>›</span>
          </Link>
        ))}
      </div>
    </Shell>
  )
}
