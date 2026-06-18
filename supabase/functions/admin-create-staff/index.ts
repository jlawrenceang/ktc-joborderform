// Owner-only: invite a staff member by email. This is the ONLY way a staff role
// is granted — there is no synthetic-account / owner-sets-password path and no
// "grant admin to an existing email" shortcut.
//
// Flow: owner enters email + full name + role -> GoTrue inviteUserByEmail creates
// the user (no password) and emails a branded invite link -> the invitee clicks,
// lands on /reset-password, and sets their own password. The role is assigned
// here (promote_new_staff, run AS THE OWNER so the audit attributes the grant).
//
// Security: owner ONLY, evaluated by the DB as the caller (is_owner() folds in
// MFA aal2 + session-alive). redirect_to is allow-listed to the portal origin.
import { createClient } from 'npm:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })

const ROLES = ['admin', 'cashier', 'checker', 'operations', 'csr']
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !serviceKey || !anonKey) return json({ error: 'Function not configured.' }, 500)

  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!jwt) return json({ error: 'Missing authorization.' }, 401)

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })

  // 1) Verify the session.
  const { data: u, error: uErr } = await admin.auth.getUser(jwt)
  if (uErr || !u.user) return json({ error: 'Invalid session.' }, 401)

  // 2) Caller must be the OWNER — evaluated by the DB as the caller (aal2 + alive).
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: isOwner, error: ownErr } = await callerClient.rpc('is_owner')
  if (ownErr) return json({ error: 'Authorization check failed.' }, 500)
  if (isOwner !== true) return json({ error: 'Only the owner can invite staff (complete MFA if enabled).' }, 403)

  // 3) Validate input.
  let body: { email?: string; full_name?: string; role?: string; redirect_to?: string }
  try { body = await req.json() } catch { return json({ error: 'Bad request body.' }, 400) }
  const email = (body.email ?? '').trim().toLowerCase()
  const fullName = (body.full_name ?? '').trim()
  const role = (body.role ?? 'admin').trim()
  if (!EMAIL_RE.test(email)) return json({ error: 'Enter a valid email address.' }, 400)
  if (!ROLES.includes(role)) return json({ error: `Unknown role ${role}.` }, 400)
  if (!fullName) return json({ error: 'Full name is required.' }, 400)

  // Allow-list the post-invite landing to the portal origin (defense-in-depth).
  const safeRedirect = (input?: string): string => {
    const fallback = 'https://portal.ktcterminal.com/reset-password'
    if (!input) return fallback
    try {
      const r = new URL(input)
      if (r.protocol === 'https:' && (r.hostname === 'ktcterminal.com' || r.hostname.endsWith('.ktcterminal.com'))) {
        return `${r.origin}/reset-password`
      }
    } catch { /* not absolute */ }
    return fallback
  }

  // 4) Invite: creates the user (no password) + emails the branded invite link.
  //    handle_new_user makes the public.customers row from the metadata.
  const { data: invited, error: iErr } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name: fullName },
    redirectTo: safeRedirect(body.redirect_to),
  })
  if (iErr || !invited.user) {
    const msg = /registered|exists|already/i.test(iErr?.message ?? '')
      ? 'That email already has an account.'
      : (iErr?.message ?? 'Could not send the invite.')
    return json({ error: msg }, 400)
  }

  // 5) Assign the role AS THE OWNER (audit attributes the grant to the owner).
  const { error: pErr } = await callerClient.rpc('promote_new_staff', {
    p_user_id: invited.user.id, p_role: role, p_full_name: fullName,
  })
  if (pErr) {
    await admin.auth.admin.deleteUser(invited.user.id).catch(() => undefined)
    return json({ error: `Invite sent but role assignment failed: ${pErr.message}` }, 500)
  }

  return json({ email })
})
