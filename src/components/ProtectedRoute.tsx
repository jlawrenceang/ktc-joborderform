import { Navigate } from 'react-router-dom'
import { useEffect, useState, type ReactNode } from 'react'
import { useAuth } from '../lib/AuthContext'
import { supabase } from '../lib/supabase'
import MfaChallenge from './MfaChallenge'
import SessionConflictModal from './SessionConflictModal'
import FinishRegistration from './FinishRegistration'
import ReConsent from './ReConsent'
import { AGREEMENT_VERSION } from '../content/legal'

function AwaitingEmailConfirmation({ email }: { email: string | undefined }) {
  const { signOut } = useAuth()
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  async function resend() {
    if (!email) return
    setBusy(true); setNotice(null)
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email,
      options: { emailRedirectTo: typeof window !== 'undefined' ? `${window.location.origin}/confirmed` : undefined },
    })
    setBusy(false)
    setNotice(error ? error.message : 'Confirmation email resent — check your inbox and spam folder.')
  }

  return (
    <div style={{ maxWidth: 460, margin: '0 auto', padding: '64px 24px' }}>
      <div className="ktc-glass" style={{ padding: 18 }}>
        <h1 className="ktc-title">Awaiting email confirmation</h1>
        <p className="ktc-label" style={{ marginTop: 10, lineHeight: 1.6 }}>
          We sent a confirmation link to <b>{email}</b>. Please check your <b>inbox</b> — and your
          <b> spam / junk folder</b> — and click the link to confirm your email. Once confirmed, sign
          in to upload your valid ID for final verification.
        </p>
        {notice && <p className="ktc-label" style={{ marginTop: 12, fontSize: 13 }}>{notice}</p>}
        <div style={{ display: 'flex', gap: 10, marginTop: 18, flexWrap: 'wrap' }}>
          <button
            type="button"
            disabled={busy}
            onClick={() => void resend()}
            style={{ border: 0, borderRadius: 10, padding: '9px 16px', fontWeight: 600, fontSize: 13, cursor: 'pointer', color: '#fff', background: 'linear-gradient(135deg, var(--acc), var(--acc-2))' }}
          >
            {busy ? 'Resending…' : 'Resend confirmation email'}
          </button>
          <button
            type="button"
            onClick={() => void signOut()}
            style={{ border: '1px solid hsl(var(--line))', borderRadius: 10, padding: '9px 16px', fontWeight: 600, fontSize: 13, cursor: 'pointer', background: 'var(--c-w70)', color: 'hsl(var(--ink-2))' }}
          >
            Back to sign in
          </button>
        </div>
      </div>
    </div>
  )
}

export default function ProtectedRoute({ children }: { children: ReactNode }) {
  const { session, loading, sessionClaim, runSessionClaim } = useAuth()

  // MFA gate: an account with a verified TOTP factor must pass the challenge
  // (aal2) before the portal renders. Backend-enforced too — is_admin() /
  // has_permission() return false at aal1 for enrolled accounts.
  const [aal, setAal] = useState<{ current: string; next: string } | null>(null)
  useEffect(() => {
    if (!session) { setAal(null); return }
    let active = true
    void supabase.auth.mfa.getAuthenticatorAssuranceLevel().then(({ data }) => {
      if (active) setAal({ current: data?.currentLevel ?? 'aal1', next: data?.nextLevel ?? 'aal1' })
    })
    return () => { active = false }
  }, [session])

  // Single-session gate: once the session is fully authenticated (past the
  // email + MFA gates), run the claim check exactly once. It either claims
  // silently (no other device) or holds at 'conflict' for Terminate/Cancel.
  const sessionUser = session?.user
  const isStaffEarly = !!sessionUser?.email?.endsWith('@ktc-staff.local')
  const emailOk = !!(sessionUser?.email_confirmed_at || sessionUser?.confirmed_at)
  const aalReady = !!aal && !(aal.next === 'aal2' && aal.current !== 'aal2')
  const fullyAuthed = !!session && (isStaffEarly || emailOk) && aalReady
  useEffect(() => {
    if (fullyAuthed) runSessionClaim()
  }, [fullyAuthed, runSessionClaim])

  // OAuth (Google) registration gate: a Google sign-up hasn't agreed to the
  // Customer Agreement or given a contact number yet (the email/password form
  // collects both). Check the customer's recorded consent — SCOPED to OAuth
  // users, so an email/password customer skips this read + gate entirely.
  const isOauthUser = (session?.user?.app_metadata as { provider?: string } | undefined)?.provider === 'google'
  const [oauthReg, setOauthReg] = useState<'unknown' | 'needed' | 'done'>('unknown')
  useEffect(() => {
    if (!isOauthUser || !session) return
    let active = true
    void supabase.from('customers').select('terms_version').eq('user_id', session.user.id).maybeSingle()
      .then(({ data }) => { if (active) setOauthReg((data as { terms_version: string | null } | null)?.terms_version ? 'done' : 'needed') })
    return () => { active = false }
  }, [isOauthUser, session])

  // Re-consent gate: a customer whose recorded agreement version no longer matches the current
  // AGREEMENT_VERSION must re-accept before the portal renders (has_recorded_consent() only checks
  // the version is non-null, so a bump never re-gated). Scoped to customers (staff_role null);
  // staff/owner hold no agreement, and a missing row isn't a consenting customer either. (T1-07)
  const [consent, setConsent] = useState<'unknown' | 'ok' | 'needed'>('unknown')
  useEffect(() => {
    if (!session) { setConsent('unknown'); return }
    let active = true
    void supabase.from('customers').select('staff_role, terms_version').eq('user_id', session.user.id).maybeSingle()
      .then(({ data }) => {
        if (!active) return
        const row = data as { staff_role: string | null; terms_version: string | null } | null
        if (!row || row.staff_role) { setConsent('ok'); return }
        setConsent(row.terms_version === AGREEMENT_VERSION ? 'ok' : 'needed')
      })
    return () => { active = false }
  }, [session])

  if (loading) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (!session) return <Navigate to="/login" replace />

  // Email-confirmation gate: a real-email broker must confirm their email before
  // they can reach the portal. Staff use synthetic @ktc-staff.local logins (server-
  // created, no real mailbox) so they're exempt. This backs up Supabase's
  // "Confirm email" setting — the portal must never render for an unverified email.
  const user = session.user
  const isStaff = !!user.email?.endsWith('@ktc-staff.local')
  const emailConfirmed = !!(user.email_confirmed_at || user.confirmed_at)
  if (!isStaff && !emailConfirmed) {
    return <AwaitingEmailConfirmation email={user.email} />
  }

  if (!aal) {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (aal.next === 'aal2' && aal.current !== 'aal2') {
    return <MfaChallenge onVerified={() => setAal({ current: 'aal2', next: 'aal2' })} />
  }

  // Single-session gate: another device is live → ask before evicting.
  if (sessionClaim === 'conflict') return <SessionConflictModal />
  // 'idle' / 'checking' → the claim check is in flight; hold the portal back a
  // beat so it can't flash before a possible conflict prompt.
  if (sessionClaim !== 'resolved') {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }

  // Google sign-ups: hold for the consent check, then collect agreement + contact.
  if (isOauthUser && oauthReg === 'unknown') {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (isOauthUser && oauthReg === 'needed') {
    return <FinishRegistration onDone={() => { setOauthReg('done'); setConsent('ok') }} />
  }

  // Re-consent gate (customers only): hold until known, block on an agreement-version mismatch.
  if (consent === 'unknown') {
    return (
      <div style={{ display: 'grid', placeItems: 'center', height: '100%' }}>
        <span className="ktc-label">Loading…</span>
      </div>
    )
  }
  if (consent === 'needed') return <ReConsent onDone={() => setConsent('ok')} />

  return <>{children}</>
}
