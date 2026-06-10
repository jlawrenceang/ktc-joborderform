// Print the project's Auth rate-limit + security settings via the Supabase
// Management API, so we can verify the server-side limits that back the
// (cosmetic) client-side login lockout. Read-only.
//
// Reads from the gitignored .env.local:
//   SUPABASE_ACCESS_TOKEN=sbp_...
//   VITE_SUPABASE_URL=https://<ref>.supabase.co
//
// Usage:  node scripts/check-auth-rate-limits.mjs
import { readFileSync, existsSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const raw = existsSync(path.join(root, '.env.local')) ? readFileSync(path.join(root, '.env.local'), 'utf8') : ''
const get = (k) => {
  const m = raw.match(new RegExp('^\\s*' + k + '\\s*=\\s*(.*)$', 'm'))
  return m ? m[1].trim().replace(/^["']|["']$/g, '') : null
}

const token = get('SUPABASE_ACCESS_TOKEN')
const url = get('VITE_SUPABASE_URL')
if (!token) { console.error('Add SUPABASE_ACCESS_TOKEN to .env.local (Supabase Dashboard > Account > Access Tokens).'); process.exit(1) }
if (!url) { console.error('VITE_SUPABASE_URL missing from .env.local'); process.exit(1) }
const ref = new URL(url).host.split('.')[0]

const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
  headers: { Authorization: `Bearer ${token}` },
})
if (!res.ok) { console.error(`GET failed: ${res.status} ${await res.text()}`); process.exit(1) }
const cfg = await res.json()

const keys = Object.keys(cfg).filter((k) =>
  k.startsWith('rate_limit') || ['security_captcha_enabled', 'password_min_length', 'password_required_characters', 'mailer_otp_exp', 'security_refresh_token_reuse_interval', 'sessions_timebox', 'sessions_inactivity_timeout'].includes(k),
).sort()
for (const k of keys) console.log(`${k} = ${JSON.stringify(cfg[k])}`)
