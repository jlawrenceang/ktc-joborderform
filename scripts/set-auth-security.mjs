// Tighten server-side Auth security settings via the Supabase Management API.
// (These live in GoTrue config, not the Postgres DB, so no migration can set them.)
//
//   - password_min_length: 8 (was 6). Applies to NEW passwords only — existing
//     users keep signing in with their current password.
//   - password_required_characters: at least one letter AND one digit.
//   - rate_limit_email_sent: 30/hour (was 100) — confirm/reset/change emails.
//
// Reads from the gitignored .env.local:
//   SUPABASE_ACCESS_TOKEN=sbp_...
//   VITE_SUPABASE_URL=https://<ref>.supabase.co
//
// Usage:  node scripts/set-auth-security.mjs
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

const body = {
  password_min_length: 8,
  // colon-separated groups; a new password must contain ≥1 char from each group
  password_required_characters: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ:0123456789',
  rate_limit_email_sent: 30,
}

const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
  method: 'PATCH',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})
if (!res.ok) { console.error(`PATCH failed: ${res.status} ${await res.text()}`); process.exit(1) }
const cfg = await res.json()
console.log('ok — applied:')
console.log(`  password_min_length = ${cfg.password_min_length}`)
console.log(`  password_required_characters = ${JSON.stringify(cfg.password_required_characters)}`)
console.log(`  rate_limit_email_sent = ${cfg.rate_limit_email_sent}`)
