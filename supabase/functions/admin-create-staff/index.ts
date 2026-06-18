// Owner-only: create a staff account. Replaces the hand-written auth.users /
// auth.identities INSERT (create_staff RPC) — Supabase/GoTrue now owns the auth
// row internals, so we stop duplicating bcrypt + identity bookkeeping that could
// drift from a future GoTrue schema change.
//
// Staff stay INVITE-ONLY: no self-signup, no email confirmation step. Accounts
// use synthetic <username>@ktc-staff.local emails (no real inbox needed — ideal
// for shared/kiosk devices) and are created already-confirmed (email_confirm).
//
// Security: owner ONLY, evaluated by the DB AS THE CALLER (is_owner() folds in
// MFA aal2 + session-alive). The privilege grant runs through promote_new_staff
// under the OWNER's JWT, so the audit trail attributes it to the owner (not a
// service-role/by-DB write). Mirrors admin-reset-link's runtime conventions.
//
// Invoked from Settings: supabase.functions.invoke('admin-create-staff',
//   { body: { username, password, full_name, role } }).
import { createClient } from 'npm:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } })

const ROLES = ['admin', 'cashier', 'checker', 'operations', 'csr']

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
  if (isOwner !== true) return json({ error: 'Only the owner can create staff (complete MFA if enabled).' }, 403)

  // 3) Validate input.
  let body: { username?: string; password?: string; full_name?: string; role?: string }
  try { body = await req.json() } catch { return json({ error: 'Bad request body.' }, 400) }
  const username = (body.username ?? '').trim().toLowerCase()
  const password = body.password ?? ''
  const fullName = (body.full_name ?? '').trim()
  const role = (body.role ?? 'admin').trim()
  if (username.length < 3) return json({ error: 'Username must be at least 3 characters.' }, 400)
  if (!ROLES.includes(role)) return json({ error: `Unknown role ${role}.` }, 400)
  if (!fullName) return json({ error: 'Full name is required.' }, 400)
  if (password.length < 8 || !/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
    return json({ error: 'Password must be at least 8 characters and include a letter and a number.' }, 400)
  }
  const email = `${username}@ktc-staff.local`

  // 4) Create the auth user via GoTrue (already-confirmed; metadata feeds the
  //    handle_new_user trigger that makes the public.customers row).
  const { data: created, error: cErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, username },
  })
  if (cErr || !created.user) {
    const msg = /registered|exists|duplicate/i.test(cErr?.message ?? '') ? 'That username is already taken.' : (cErr?.message ?? 'Could not create the account.')
    return json({ error: msg }, 400)
  }

  // 5) Promote the new row AS THE OWNER (audit attributes the grant to the owner).
  const { error: pErr } = await callerClient.rpc('promote_new_staff', {
    p_user_id: created.user.id, p_role: role, p_full_name: fullName,
  })
  if (pErr) {
    // Roll back the auth user so a half-made account isn't left behind.
    await admin.auth.admin.deleteUser(created.user.id).catch(() => undefined)
    return json({ error: `Account created but role assignment failed: ${pErr.message}` }, 500)
  }

  return json({ email })
})
