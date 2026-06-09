import { Navigate } from 'react-router-dom'
import { useState, type ReactNode } from 'react'
import { useAuth } from '../lib/AuthContext'
import { supabase } from '../lib/supabase'

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
      options: { emailRedirectTo: typeof window !== 'undefined' ? `${window.location.origin}/verify-id` : undefined },
    })
    setBusy(false)
    setNotice(error ? error.message : 'Confirmation email resent — check your inbox and spam folder.')
  }

  return (
    <div style={{ maxWidth: 460, margin: '0 auto', padding: '64px 24px' }}>
      <div className="ktc-glass" style={{ padding: 28 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>Awaiting email confirmation</h1>
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
            style={{ border: '1px solid hsl(var(--line))', borderRadius: 10, padding: '9px 16px', fontWeight: 600, fontSize: 13, cursor: 'pointer', background: 'rgba(255,255,255,0.7)', color: 'hsl(var(--ink-2))' }}
          >
            Back to sign in
          </button>
        </div>
      </div>
    </div>
  )
}

export default function ProtectedRoute({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth()
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

  return <>{children}</>
}
