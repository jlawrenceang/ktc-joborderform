import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { prepareUpload } from '../lib/validation'
import { useFileViewer } from './FileViewerModal'
import { useT } from '../lib/i18n'

// Supporting info on a Job Order: a note and/or a document (packing list,
// proforma, corrected entry…) the customer can attach to an ACTIVE order to
// speed up verification. Reused read-only on the admin side (active=false →
// list only, no form). Reads job_order_documents (RLS gates rows); writes go
// through the add_jo_support RPC (migration 0069).
type DocRow = { id: string; path: string | null; filename: string | null; note: string | null; created_at: string }

export default function JoSupport({ orderId, userId, active, hideWhenEmpty = false }: { orderId: string; userId: string; active: boolean; hideWhenEmpty?: boolean }) {
  const { t } = useT()
  const [docs, setDocs] = useState<DocRow[]>([])
  const [note, setNote] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)
  const { openFromStorage, viewerModal } = useFileViewer(setErr)

  async function loadDocs() {
    const { data } = await supabase
      .from('job_order_documents')
      .select('id, path, filename, note, created_at')
      .eq('job_order_id', orderId)
      .order('created_at', { ascending: false })
    setDocs((data ?? []) as DocRow[])
  }
  useEffect(() => { void loadDocs() }, [orderId]) // eslint-disable-line react-hooks/exhaustive-deps

  async function submit() {
    if (!note.trim() && !file) { setErr(t('Add a note or attach a document.')); return }
    setBusy(true); setErr(null)
    let path: string | null = null
    let filename: string | null = null
    if (file) {
      const prepared = await prepareUpload(file)
      if ('error' in prepared) { setBusy(false); setErr(prepared.error); return }
      const safe = prepared.file.name.replace(/[^A-Za-z0-9._-]/g, '_')
      path = `${userId}/${orderId}/${Date.now()}_${safe}`
      filename = file.name
      const { error: upErr } = await supabase.storage.from('jo-documents').upload(path, prepared.file, { upsert: false })
      if (upErr) { setBusy(false); setErr(upErr.message); return }
    }
    const { error: rpcErr } = await supabase.rpc('add_jo_support', { p_jo: orderId, p_path: path, p_filename: filename, p_note: note.trim() || null })
    setBusy(false)
    if (rpcErr) { setErr(rpcErr.message); return }
    setNote(''); setFile(null)
    void loadDocs()
  }

  // Admin/read-only cards stay clean until something's actually attached.
  if (!active && hideWhenEmpty && docs.length === 0) return null

  return (
    <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid var(--glass-brd)' }}>
      <span className="ktc-label" style={{ fontSize: 12, fontWeight: 600 }}>{t('Supporting info & documents')}</span>
      {active && (
        <p className="ktc-label" style={{ fontSize: 11.5, opacity: 0.8, marginTop: 2, lineHeight: 1.5 }}>
          {t('Optional — add a note or attach a document (e.g. packing list, proforma) to help KTC verify and process this order faster.')}
        </p>
      )}

      {docs.length > 0 && (
        <div style={{ display: 'grid', gap: 6, margin: '10px 0' }}>
          {docs.map((d) => (
            <div key={d.id} style={{ padding: '9px 12px', borderRadius: 9, background: 'var(--c-w60)', border: '1px solid var(--glass-brd)' }}>
              {d.note && <div style={{ fontSize: 13, lineHeight: 1.45 }}>{d.note}</div>}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginTop: d.note ? 4 : 0 }}>
                {d.path && (
                  <button type="button" className="ktc-link" style={{ fontSize: 12.5 }}
                    onClick={() => void openFromStorage('jo-documents', d.path!, d.filename ?? t('Document'))}>
                    📎 {d.filename ?? t('View document')}
                  </button>
                )}
                <span className="ktc-label" style={{ fontSize: 11.5, opacity: 0.7, marginLeft: 'auto' }}>{new Date(d.created_at).toLocaleString()}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      {active && (
        <div style={{ display: 'grid', gap: 8, marginTop: 10 }}>
          {err && <div style={{ fontSize: 12.5, color: 'var(--acc-2)' }} role="alert">{err}</div>}
          <textarea className="ktc-input" rows={2} placeholder={t('Add a note to KTC (optional)…')} value={note} onChange={(e) => setNote(e.target.value)} />
          {file ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, padding: '8px 12px', borderRadius: 9, background: 'var(--c-w60)', border: '1px solid var(--glass-brd)' }}>
              <span style={{ flex: '1 1 auto', wordBreak: 'break-all' }}>📎 {file.name}</span>
              <button type="button" className="ktc-link" style={{ fontSize: 12.5, color: 'var(--acc-2)' }} onClick={() => setFile(null)}>{t('Remove')}</button>
            </div>
          ) : (
            <input className="ktc-input" type="file" accept="image/*,application/pdf" style={{ padding: '9px 12px', fontSize: 13 }}
              onChange={(e) => { const f = e.target.files?.[0]; if (f) setFile(f) }} />
          )}
          <button type="button" className="ktc-btn ktc-btn--sm" disabled={busy} onClick={() => void submit()} style={{ justifySelf: 'start' }}>
            {busy ? t('Sending…') : t('Send to KTC')}
          </button>
        </div>
      )}

      {!active && docs.length === 0 && (
        <p className="ktc-label" style={{ fontSize: 12.5, marginTop: 8, opacity: 0.75 }}>{t('No supporting documents attached.')}</p>
      )}
      {viewerModal}
    </div>
  )
}
