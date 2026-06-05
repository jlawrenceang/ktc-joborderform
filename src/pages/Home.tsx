import { useAuth } from '../lib/AuthContext'

export default function Home() {
  const { session, signOut } = useAuth()

  return (
    <div style={{ maxWidth: 760, margin: '0 auto', padding: '40px 24px' }}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
        <img src="/ktc-logo.png" alt="KTC Container Terminal Corp" style={{ height: 56 }} />
        <button className="ktc-link" onClick={() => void signOut()}>Sign out</button>
      </header>

      <div className="ktc-glass" style={{ padding: 28, marginBottom: 18 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>
          Welcome{session?.user.email ? `, ${session.user.email}` : ''}
        </h1>
        <p className="ktc-label" style={{ marginTop: 8 }}>
          This is the KTC Job Order portal. From here you'll create job orders against your
          accredited consignees, and manage your accreditation requests.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16 }}>
        {[
          { title: 'New Job Order', desc: 'Submit X-ray / DEA / OOG stripping requests.' },
          { title: 'My Accreditations', desc: 'Request and track consignee accreditations.' },
          { title: 'My Job Orders', desc: 'View previously submitted job orders.' },
        ].map((c) => (
          <div key={c.title} className="ktc-glass" style={{ padding: 22, borderRadius: 'var(--radius-lg)' }}>
            <h2 style={{ margin: 0, fontSize: 16, fontWeight: 600 }}>{c.title}</h2>
            <p className="ktc-label" style={{ marginTop: 6, fontSize: 13 }}>{c.desc}</p>
            <p className="ktc-label" style={{ marginTop: 12, fontSize: 12, opacity: 0.7 }}>Coming next</p>
          </div>
        ))}
      </div>
    </div>
  )
}
