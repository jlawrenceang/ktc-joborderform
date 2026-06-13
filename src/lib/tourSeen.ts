import { supabase } from './supabase'

// Per-PAGE "tour seen" — durable per account (customers.tours_seen, appended by
// the mark_tour_seen RPC, migration 0066). A per-session flag also stops a
// page tour re-opening on remounts within one session.
const sessionKey = (page: string) => `ktc_tour_shown_${page}`

export function pageTourShownThisSession(page: string): boolean {
  try { return sessionStorage.getItem(sessionKey(page)) === '1' } catch { return false }
}

export function markPageTourSeen(page: string) {
  try { sessionStorage.setItem(sessionKey(page), '1') } catch { /* ignore */ }
  void supabase.rpc('mark_tour_seen', { p_page: page })
}
