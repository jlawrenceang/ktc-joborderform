// "Batch" = the day a job order was filed (Asia/Manila). This replaces the
// per-order priority / serving number: orders are grouped by filing day, and
// AGING (time since filing) is what ops watches to keep turnaround down. No DB
// change — both are derived from job_orders.created_at.
const TZ = 'Asia/Manila'

function manilaYmd(ms: number): string {
  return new Date(ms).toLocaleDateString('en-CA', { timeZone: TZ }) // YYYY-MM-DD
}

/** Friendly batch label: "Today" / "Yesterday" / "Jun 19, 2026" (Manila day). */
export function batchLabel(iso: string, t: (s: string) => string = (s) => s): string {
  const ms = new Date(iso).getTime()
  const day = manilaYmd(ms)
  const now = Date.now()
  if (day === manilaYmd(now)) return t('Today')
  if (day === manilaYmd(now - 86_400_000)) return t('Yesterday')
  return new Date(ms).toLocaleDateString('en-US', { timeZone: TZ, month: 'short', day: 'numeric', year: 'numeric' })
}

/** Compact elapsed time since filing, e.g. "1d 4h", "5h 12m", "37m". */
export function formatAge(fromIso: string, toIso?: string | null): string {
  const from = new Date(fromIso).getTime()
  const to = toIso ? new Date(toIso).getTime() : Date.now()
  let mins = Math.max(0, Math.round((to - from) / 60_000))
  const d = Math.floor(mins / 1440); mins -= d * 1440
  const h = Math.floor(mins / 60); const m = mins - h * 60
  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

/** Hours elapsed since filing (for threshold coloring). */
export function ageHours(fromIso: string, toIso?: string | null): number {
  const to = toIso ? new Date(toIso).getTime() : Date.now()
  return (to - new Date(fromIso).getTime()) / 3_600_000
}
