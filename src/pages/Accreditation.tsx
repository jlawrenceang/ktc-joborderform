import { Link } from 'react-router-dom'
import Shell from '../components/Shell'

// Per-broker consignee accreditation is disabled for now (2026-06-09): any
// registered broker can pick any consignee from the master list directly on the
// New Job Order form. This page is kept as a route so existing links don't break
// and the flow can be re-enabled later. See ADR-0007.
export default function Accreditation() {
  return (
    <Shell>
      <div className="ktc-glass" style={{ padding: 28 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>Accreditation</h1>
        <p className="ktc-label" style={{ marginTop: 10, lineHeight: 1.6 }}>
          Consignee accreditation isn't required right now. You can select any consignee directly when you
          create a job order.
        </p>
        <Link to="/job-order" className="ktc-btn" style={{ display: 'inline-block', width: 'auto', padding: '11px 18px', marginTop: 14, textDecoration: 'none' }}>
          New Job Order
        </Link>
      </div>
    </Shell>
  )
}
