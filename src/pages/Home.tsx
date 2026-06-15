import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Shell from '../components/Shell'
import { supabase } from '../lib/supabase'
import { useAuth } from '../lib/AuthContext'
import { useBroker } from '../lib/useBroker'
import { homeSteps } from '../components/WelcomeTour'
import { usePageTour } from '../components/TourProvider'
import NotificationBar from '../components/NotificationBar'
import { useT } from '../lib/i18n'

// Home is an at-a-glance OVERVIEW (not a launcher — navigation lives in the
// bottom bar). Shows order counts, notifications, and a small bulletin. The ⊞
// Menu in the bottom bar carries the full launcher grid.
export default function Home() {
  const { session } = useAuth()
  const { broker } = useBroker()
  const { t } = useT()
  const firstName = (broker?.full_name || session?.user.email || '').split(' ')[0]

  // First visit to Home auto-opens its tour; replay from the ⊞ Menu.
  usePageTour('home', homeSteps)

  const [active, setActive] = useState<number | null>(null)
  const [attention, setAttention] = useState<number | null>(null)
  const [completed, setCompleted] = useState<number | null>(null)

  useEffect(() => {
    void supabase.from('job_orders').select('id', { count: 'exact', head: true })
      .in('status', ['held', 'submitted', 'processing', 'on_hold'])
      .then(({ count }) => setActive(count ?? 0))
    void supabase.from('job_orders').select('id', { count: 'exact', head: true })
      .or('status.eq.on_hold,and(status.eq.rejected,rejected_recoverable.eq.true),and(payment_status.eq.rejected,status.in.(submitted,processing,completed))')
      .then(({ count }) => setAttention(count ?? 0))
    void supabase.from('job_orders').select('id', { count: 'exact', head: true })
      .eq('status', 'completed')
      .then(({ count }) => setCompleted(count ?? 0))
  }, [])

  const stat = (n: number | null) => (n === null ? '—' : String(n))

  return (
    <Shell>
      <div className="ktc-home-head">
        <span className="ktc-home-eyebrow">{t('Dashboard')}</span>
        <h1 className="ktc-home-greet">
          {firstName ? t('Welcome, {name}', { name: firstName }) : t('Welcome')}
        </h1>
        <p className="ktc-sub" style={{ maxWidth: 460, marginBottom: 0 }}>
          {t('Here’s what’s happening with your KTC terminal services.')}
        </p>
      </div>

      <NotificationBar />

      <div className="ktc-stat-grid" data-tour="home-stats">
        <Link to="/job-orders" className="ktc-glass ktc-stat">
          <span className="ktc-stat-num">{stat(active)}</span>
          <span className="ktc-stat-label">{t('Active orders')}</span>
        </Link>
        <Link to="/job-orders" className={`ktc-glass ktc-stat${attention ? ' ktc-stat--alert' : ''}`}>
          <span className="ktc-stat-num">{stat(attention)}</span>
          <span className="ktc-stat-label">{t('Needs your attention')}</span>
        </Link>
        <Link to="/job-orders" className="ktc-glass ktc-stat">
          <span className="ktc-stat-num">{stat(completed)}</span>
          <span className="ktc-stat-label">{t('Completed')}</span>
        </Link>
      </div>

      <div className="ktc-glass ktc-bulletin" data-tour="home-bulletin">
        <h2 className="ktc-bulletin-title">📌 {t('Good to know')}</h2>
        <ul className="ktc-bulletin-list">
          <li>{t('Vessel schedules can change (delays / advances) — check before you file.')}</li>
          <li>{t('Estimate your charges with the Rate Calculator before filing.')}</li>
          <li>{t('Pay online and upload your slip to speed up processing.')}</li>
        </ul>
        <div className="ktc-bulletin-links">
          <Link to="/vessels" className="ktc-btn-secondary ktc-btn--sm" style={{ textDecoration: 'none' }}>{t('Vessel Schedule')}</Link>
          <Link to="/calculator" className="ktc-btn-secondary ktc-btn--sm" style={{ textDecoration: 'none' }}>{t('Rate Calculator')}</Link>
        </div>
      </div>
    </Shell>
  )
}
