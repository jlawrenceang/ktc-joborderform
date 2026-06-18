// Install the branded "Confirm signup" email template + subject into Supabase
// Auth, via the Supabase Management API. The email template lives in GoTrue config
// (NOT the Postgres DB), so this is the only programmatic way to set it.
//
// Reads from the gitignored .env.local:
//   SUPABASE_ACCESS_TOKEN=sbp_...        (required — Dashboard > Account > Access Tokens)
//   VITE_SUPABASE_URL=https://<ref>.supabase.co   (used to derive the project ref)
//
// Usage:  node scripts/set-auth-email-template.mjs
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

const readTpl = (f) => readFileSync(path.join(root, 'docs/email-templates', f), 'utf8').replace(/<!--[\s\S]*?-->/, '').trim()
const confirmHtml = readTpl('confirm-signup.html')
const resetHtml = readTpl('reset-password.html')
const inviteHtml = readTpl('invite-staff.html')

const body = {
  mailer_subjects_confirmation: 'Confirm your KTC Online Portal account',
  mailer_templates_confirmation_content: confirmHtml,
  mailer_subjects_recovery: 'Reset your KTC Online Portal password',
  mailer_templates_recovery_content: resetHtml,
  // Staff invite (GoTrue "Invite user") — the only way a staff role is granted.
  mailer_subjects_invite: "You've been invited to the KTC Online Portal",
  mailer_templates_invite_content: inviteHtml,
}

const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
  method: 'PATCH',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})
const out = await res.json().catch(() => ({}))
console.log('project ref:', ref)
console.log('PATCH /config/auth status:', res.status)
if (res.ok) {
  console.log('✓ Confirm-signup + reset-password + staff-invite templates installed.')
  console.log('  confirm:', out.mailer_subjects_confirmation, '—', (out.mailer_templates_confirmation_content || '').length, 'chars')
  console.log('  recovery:', out.mailer_subjects_recovery, '—', (out.mailer_templates_recovery_content || '').length, 'chars')
  console.log('  invite:', out.mailer_subjects_invite, '—', (out.mailer_templates_invite_content || '').length, 'chars')
} else {
  console.log(JSON.stringify(out).slice(0, 400))
}
