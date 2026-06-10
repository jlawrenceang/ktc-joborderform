import type { ReactNode, CSSProperties } from 'react'

// One canonical notification/alert style used everywhere (login bubbles, the
// pending-verification banner, inline form messages) so they all read the same.
export type NoticeTone = 'success' | 'error' | 'warning' | 'info'

const TONES: Record<NoticeTone, { bg: string; brd: string; ink: string; pill: string }> = {
  success: { bg: 'hsl(150 55% 95%)', brd: 'hsl(150 45% 80%)', ink: 'hsl(150 55% 26%)', pill: 'hsl(150 50% 88%)' },
  error:   { bg: 'hsl(0 75% 96%)',   brd: 'hsl(0 70% 85%)',   ink: 'hsl(0 65% 42%)',   pill: 'hsl(0 75% 92%)' },
  warning: { bg: 'hsl(40 95% 94%)',  brd: 'hsl(40 85% 78%)',  ink: 'hsl(30 75% 32%)',  pill: 'hsl(40 90% 86%)' },
  info:    { bg: 'hsl(210 60% 96%)', brd: 'hsl(210 55% 82%)', ink: 'hsl(210 55% 36%)', pill: 'hsl(210 60% 90%)' },
}

export default function Notice({
  tone = 'info',
  badge,
  title,
  action,
  style,
  children,
}: {
  tone?: NoticeTone
  badge?: string
  title?: ReactNode
  action?: ReactNode
  style?: CSSProperties
  children?: ReactNode
}) {
  const c = TONES[tone]
  const hasHead = !!(badge || title)
  return (
    <div
      role="status"
      style={{
        padding: '14px 16px',
        borderRadius: 12,
        background: c.bg,
        border: `1px solid ${c.brd}`,
        color: c.ink,
        fontSize: 13,
        lineHeight: 1.6,
        ...style,
      }}
    >
      {hasHead && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {badge && (
            <span style={{ fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 999, background: c.pill, color: c.ink, letterSpacing: '0.02em' }}>
              {badge}
            </span>
          )}
          {title && <span style={{ fontSize: 14, fontWeight: 600, letterSpacing: '-0.01em', color: 'hsl(var(--ink))' }}>{title}</span>}
        </div>
      )}
      {children != null && <div style={{ marginTop: hasHead ? 8 : 0, fontWeight: 500 }}>{children}</div>}
      {action && <div style={{ marginTop: 14 }}>{action}</div>}
    </div>
  )
}
