import { Navigate } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from '../lib/AuthContext'

export default function ProtectedRoute({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth()
  if (loading) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (!session) return <Navigate to="/login" replace />
  return <>{children}</>
}
