import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useBroker } from '../lib/useBroker'
import { hasAdminAccess } from '../lib/types'

export default function AdminRoute({ children }: { children: ReactNode }) {
  const { broker, loading } = useBroker()
  if (loading) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (!hasAdminAccess(broker)) return <Navigate to="/" replace />
  return <>{children}</>
}
