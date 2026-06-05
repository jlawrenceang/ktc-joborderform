import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anonKey) {
  // Surfaced in the console so a missing .env.local is obvious in dev.
  console.warn(
    '[KTC] Supabase env not set. Copy .env.example to .env.local and fill ' +
      'VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY from your KTC Supabase project.',
  )
}

export const supabase = createClient(url ?? '', anonKey ?? '')
