import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { usePermissions, type Permission } from '../lib/usePermissions'
import { isStaff } from '../lib/types'

// Gate for the back office. Any staff may enter the shell, but a route may ALSO
// require a specific permission (single, or any-of an array). This mirrors the
// AdminBottomNav GRID visibility 1:1 — so a role that can't see a tile can't
// reach the page by typing its URL either (previously only the nav was hidden;
// direct navigation rendered the screen and relied on in-screen + RLS gates).
// Owner passes every gate (usePermissions grants '*'). Failing the check bounces
// to '/', where RoleLanding routes the staffer to their own role home.
export default function AdminRoute({ children, perm }: { children: ReactNode; perm?: Permission | Permission[] }) {
  const { can, loading, broker } = usePermissions()
  if (loading) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (!isStaff(broker)) return <Navigate to="/" replace />
  if (perm) {
    const perms = Array.isArray(perm) ? perm : [perm]
    if (!perms.some(can)) return <Navigate to="/" replace />
  }
  return <>{children}</>
}
