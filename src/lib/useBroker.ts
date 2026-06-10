import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import type { Broker } from './types'

/**
 * Loads the signed-in user's own broker profile.
 * Must filter by user_id: admins can read ALL broker rows (RLS), so an
 * unfiltered .maybeSingle() would error on multiple rows and return null.
 *
 * `refresh()` refetches in place (no loading flash) — used by the pending
 * banner so a customer can pull their latest status without a page reload.
 */
export function useBroker() {
  const [broker, setBroker] = useState<Broker | null>(null)
  const [loading, setLoading] = useState(true)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    let active = true
    supabase.auth.getSession().then(({ data }) => {
      const uid = data.session?.user.id
      if (!uid) {
        if (active) {
          setBroker(null)
          setLoading(false)
        }
        return
      }
      supabase
        .from('customers')
        .select('*')
        .eq('user_id', uid)
        .maybeSingle()
        .then(({ data: row }) => {
          if (active) {
            setBroker((row as Broker) ?? null)
            setLoading(false)
          }
        })
    })
    return () => {
      active = false
    }
  }, [refreshKey])

  const refresh = useCallback(() => setRefreshKey((k) => k + 1), [])

  return { broker, loading, refresh }
}
