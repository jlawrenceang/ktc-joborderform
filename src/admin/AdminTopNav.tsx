import { NavLink } from 'react-router-dom'
import { usePermissions } from '../lib/usePermissions'
import { useAdminCounts } from '../lib/useAdminCounts'
import { useT } from '../lib/i18n'
import { GRID, canSee } from './AdminBottomNav'

// Desktop (≥1280px) horizontal admin nav — the dense ops-console nav. Hidden
// ≤1279px via CSS (.ktc-admin-topnav { display: none }), where the floating
// bottom-tab is the navigation instead. Renders the same permission-gated GRID
// destinations the ⊞ Menu does (Language/Dark-mode/Sign-out stay in the top-rail
// AccountMenu at every width, so nothing is lost when the bottom-tab hides here).
export default function AdminTopNav() {
  const { t } = useT()
  const { can } = usePermissions()
  const counts = useAdminCounts()
  const grid = GRID.filter((g) => canSee(g, can))
  return (
    <nav className="ktc-admin-topnav" aria-label={t('Admin sections')}>
      {grid.map((g) => {
        const n = counts[g.to] ?? 0
        return (
          <NavLink key={g.to} to={g.to} end={g.end}
            className={({ isActive }) => `ktc-nav-link${isActive ? ' is-active' : ''}`}>
            {t(g.label)}
            {n > 0 && <span aria-hidden className="ktc-tab-badge" style={{ position: 'static', marginLeft: 6 }}>{n > 99 ? '99+' : n}</span>}
          </NavLink>
        )
      })}
    </nav>
  )
}
