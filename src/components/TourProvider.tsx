import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'
import Tour, { type TourStep } from './Tour'
import { useBroker } from '../lib/useBroker'
import { pageTourShownThisSession, markPageTourSeen } from '../lib/tourSeen'

// Hosts the Tour ABOVE the routes so it survives navigation. Pages register
// their own short tour via usePageTour — it auto-opens the first time the
// account lands on that page, and the help (?) icon replays the current page's.

interface TourConfig { steps: TourStep[]; home?: string; label?: string; onDone?: () => void }
interface TourCtx {
  startTour: (c: TourConfig) => void
  active: boolean
  registerPageTour: (key: string | null, steps: TourStep[]) => void
  replayPageTour: () => void
  hasPageTour: boolean
}

const Ctx = createContext<TourCtx>({
  startTour: () => {}, active: false, registerPageTour: () => {}, replayPageTour: () => {}, hasPageTour: false,
})
export function useTour() { return useContext(Ctx) }

export default function TourProvider({ children }: { children: ReactNode }) {
  const [config, setConfig] = useState<TourConfig | null>(null)
  const pageTourRef = useRef<{ key: string; steps: TourStep[] } | null>(null)
  const [hasPageTour, setHasPageTour] = useState(false)

  const startTour = useCallback((c: TourConfig) => setConfig(c), [])
  const registerPageTour = useCallback((key: string | null, steps: TourStep[]) => {
    pageTourRef.current = key ? { key, steps } : null
    setHasPageTour(!!key)
  }, [])
  const replayPageTour = useCallback(() => {
    if (pageTourRef.current) setConfig({ steps: pageTourRef.current.steps })
  }, [])

  function end() {
    const done = config?.onDone
    setConfig(null)
    done?.()
  }

  return (
    <Ctx.Provider value={{ startTour, active: !!config, registerPageTour, replayPageTour, hasPageTour }}>
      {children}
      {config && <Tour steps={config.steps} home={config.home} label={config.label} onClose={end} />}
    </Ctx.Provider>
  )
}

// Each page calls this with a STABLE key + steps (define steps as a module
// const). First visit (per account, per session) auto-opens; the page tour is
// registered so the help (?) icon can replay it on demand.
export function usePageTour(key: string, steps: TourStep[]) {
  const { broker } = useBroker()
  const { startTour, active, registerPageTour } = useTour()
  useEffect(() => {
    registerPageTour(key, steps)
    return () => registerPageTour(null, [])
  }, [key]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (!broker || steps.length === 0) return
    const seen = (broker.tours_seen ?? []).includes(key)
    if (seen || pageTourShownThisSession(key) || active) return
    markPageTourSeen(key)
    startTour({ steps })
  }, [broker]) // eslint-disable-line react-hooks/exhaustive-deps
}
