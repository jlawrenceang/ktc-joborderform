import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'

// Public slip-verification page (the completed-slip QR points here). No login:
// it calls the anon `verify_job_order` RPC and confirms, live against the KTC
// database, that a Job Order is genuine and completed. Foundation for a future
// guard gate-in/out scan.
type V = { jo_number: string | null; status: string; completed_at: string | null; consignee: string | null; containers: number }

const STATUS_LABEL: Record<string, string> = {
  completed: 'Completed', processing: 'In process', on_hold: 'On hold',
  submitted: 'Filed', held: 'Draft', rejected: 'Rejected', cancelled: 'Cancelled',
}

export default function Verify() {
  const { id } = useParams<{ id: string }>()
  const [phase, setPhase] = useState<'loading' | 'found' | 'notfound'>('loading')
  const [v, setV] = useState<V | null>(null)

  useEffect(() => {
    if (!id) { setPhase('notfound'); return }
    void supabase.rpc('verify_job_order', { p_id: id }).then(({ data, error }) => {
      const row = (data as V[] | null)?.[0] ?? null
      if (error || !row) { setPhase('notfound'); return }
      setV(row); setPhase('found')
    })
  }, [id])

  const completed = v?.status === 'completed'
  const tone = phase === 'notfound' ? { bg: '#fdecea', brd: '#f3b6ad', ink: '#a31708' }
    : completed ? { bg: '#e9f7ee', brd: '#b3e3c4', ink: '#13682f' }
    : { bg: '#fff6e6', brd: '#f4c89a', ink: '#a35a16' }

  return (
    <div style={{ minHeight: '100%', background: 'hsl(220 16% 96%)', display: 'grid', placeItems: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 420, background: '#fff', borderRadius: 16, border: '1px solid #d9e0ea', boxShadow: '0 10px 40px rgb(0 0 0 / 0.08)', overflow: 'hidden', fontFamily: '-apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif', color: '#15233a' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '16px 20px', borderBottom: '1px solid #eef1f5' }}>
          <img src="/ktc-logo.png" alt="KTC" style={{ height: 30 }} />
          <div style={{ lineHeight: 1.2 }}>
            <div style={{ fontSize: 13, fontWeight: 800 }}>KTC Online Portal</div>
            <div style={{ fontSize: 11, color: '#5a6678' }}>Job Order verification</div>
          </div>
        </div>

        <div style={{ padding: 20 }}>
          {phase === 'loading' ? (
            <p style={{ textAlign: 'center', color: '#5a6678', fontSize: 14 }}>Verifying…</p>
          ) : phase === 'notfound' ? (
            <>
              <div style={{ textAlign: 'center', padding: '14px 12px', borderRadius: 12, background: tone.bg, border: `1px solid ${tone.brd}`, color: tone.ink, fontWeight: 800, fontSize: 18, letterSpacing: '0.02em' }}>
                ⚠ NOT FOUND
              </div>
              <p style={{ textAlign: 'center', fontSize: 13, color: '#5a6678', marginTop: 14 }}>
                This code doesn’t match any Job Order in the KTC system. The slip may be invalid.
              </p>
            </>
          ) : (
            <>
              <div style={{ textAlign: 'center', padding: '16px 12px', borderRadius: 12, background: tone.bg, border: `1px solid ${tone.brd}`, color: tone.ink, fontWeight: 800, fontSize: 22, letterSpacing: '0.03em' }}>
                {completed ? '✓ COMPLETED' : (STATUS_LABEL[v!.status] ?? v!.status).toUpperCase()}
              </div>
              {!completed && (
                <p style={{ textAlign: 'center', fontSize: 12.5, color: '#a35a16', marginTop: 10, fontWeight: 600 }}>
                  This Job Order is not yet completed — it is not cleared for release.
                </p>
              )}
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13.5, marginTop: 16 }}>
                <tbody>
                  <Row k="JO Number" val={v!.jo_number ?? '—'} />
                  <Row k="Status" val={STATUS_LABEL[v!.status] ?? v!.status} />
                  <Row k="Consignee" val={v!.consignee ?? '—'} />
                  <Row k="Containers" val={String(v!.containers)} />
                  {v!.completed_at && <Row k="Completed" val={new Date(v!.completed_at).toLocaleString()} />}
                </tbody>
              </table>
              <p style={{ fontSize: 11, color: '#8893a4', marginTop: 16, textAlign: 'center', lineHeight: 1.5 }}>
                Verified live against the KTC database · portal.ktcterminal.com
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function Row({ k, val }: { k: string; val: string }) {
  return (
    <tr style={{ borderBottom: '1px solid #eef1f5' }}>
      <td style={{ padding: '7px 0', color: '#5a6678', width: '38%', verticalAlign: 'top' }}>{k}</td>
      <td style={{ padding: '7px 0', fontWeight: 600 }}>{val}</td>
    </tr>
  )
}
