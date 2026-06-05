import { useEffect, useRef, useState, type FormEvent } from 'react'
import AdminShell from './AdminShell'
import { supabase } from '../lib/supabase'
import type { Consignee } from '../lib/types'

// Minimal CSV parser (handles quotes, embedded commas, CRLF).
function parseCsv(text: string): string[][] {
  const rows: string[][] = []
  let field = '', record: string[] = [], inQuotes = false, i = 0
  while (i < text.length) {
    const ch = text[i]
    if (inQuotes) {
      if (ch === '"') { if (text[i + 1] === '"') { field += '"'; i += 2; continue } inQuotes = false; i++; continue }
      field += ch; i++; continue
    }
    if (ch === '"') { inQuotes = true; i++; continue }
    if (ch === ',') { record.push(field); field = ''; i++; continue }
    if (ch === '\r') { i++; continue }
    if (ch === '\n') { record.push(field); rows.push(record); record = []; field = ''; i++; continue }
    field += ch; i++
  }
  if (field.length || record.length) { record.push(field); rows.push(record) }
  return rows
}

function rowsToConsignees(grid: string[][]): { code: string; name: string }[] {
  if (grid.length === 0) return []
  const header = grid[0].map((h) => h.trim().toLowerCase())
  const nameIdx = header.findIndex(
    (h) => h === 'name' || h === 'consignee' || h.includes('customer name') || h.includes('consignee name'),
  )
  const codeIdx = header.findIndex((h) => h === 'code')
  const nIdx = nameIdx >= 0 ? nameIdx : 1
  const cIdx = nameIdx >= 0 ? codeIdx : 0
  const body = nameIdx >= 0 ? grid.slice(1) : grid
  const seen = new Set<string>()
  const out: { code: string; name: string }[] = []
  for (const r of body) {
    const name = (r[nIdx] ?? '').trim()
    if (!name) continue
    const key = name.toLowerCase()
    if (seen.has(key)) continue
    seen.add(key)
    out.push({ code: cIdx >= 0 ? (r[cIdx] ?? '').trim() : '', name })
  }
  return out
}

function friendly(err: unknown): string {
  const e = err as { code?: string; message?: string }
  if (e?.code === '23505') return 'A consignee with that name or code already exists.'
  return e?.message ?? 'Something went wrong.'
}

const MIN_NAME = 2

export default function Consignees() {
  const [list, setList] = useState<Consignee[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [query, setQuery] = useState('')
  const [name, setName] = useState('')
  const [code, setCode] = useState('')
  const [editing, setEditing] = useState<{ id: string; code: string; name: string } | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  async function load(q = '') {
    setLoading(true)
    const s = q.replace(/[,()%*]/g, ' ').trim()
    let req = supabase.from('consignees').select('id, code, name', { count: 'exact' }).order('code').limit(200)
    if (s) req = req.or(`name.ilike.*${s}*,code.ilike.*${s}*`)
    const { data, count, error } = await req
    if (error) setError(error.message)
    else { setList((data ?? []) as Consignee[]); setTotal(count ?? 0) }
    setLoading(false)
  }

  useEffect(() => {
    const t = setTimeout(() => { void load(query) }, 300)
    return () => clearTimeout(t)
  }, [query])

  // bulk upsert for CSV import (explicit codes upsert; code-less rows insert)
  async function bulkUpsert(rows: { code: string; name: string }[]) {
    const withCode = rows.filter((r) => r.code)
    const noCode = rows.filter((r) => !r.code)
    for (let i = 0; i < withCode.length; i += 500) {
      const { error } = await supabase.from('consignees').upsert(withCode.slice(i, i + 500), { onConflict: 'code' })
      if (error) throw new Error(error.message)
    }
    for (let i = 0; i < noCode.length; i += 500) {
      const { error } = await supabase.from('consignees').insert(noCode.slice(i, i + 500).map((r) => ({ name: r.name })))
      if (error) throw new Error(error.message)
    }
  }

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setBusy(true); setError(null); setNotice(null)
    try {
      const rows = rowsToConsignees(parseCsv(await file.text()))
      if (rows.length === 0) throw new Error('No valid rows found. Expected a name column (and optional code).')
      await bulkUpsert(rows)
      setNotice(`Imported ${rows.length} row${rows.length === 1 ? '' : 's'}.`)
      await load(query)
    } catch (err) {
      setError(friendly(err))
    } finally {
      setBusy(false)
      if (fileRef.current) fileRef.current.value = ''
    }
  }

  async function addOne(e: FormEvent) {
    e.preventDefault()
    const n = name.trim(), cc = code.trim()
    if (n.length < MIN_NAME) { setError(`Name must be at least ${MIN_NAME} characters.`); return }
    setBusy(true); setError(null); setNotice(null)
    try {
      if (cc) {
        const { error } = await supabase.from('consignees').insert({ code: cc, name: n })
        if (error) throw error
        setNotice(`Added ${cc} – ${n}.`)
      } else {
        const { data, error } = await supabase.from('consignees').insert({ name: n }).select('code').single()
        if (error) throw error
        setNotice(`Added ${(data as { code: string }).code} – ${n}.`)
      }
      setName(''); setCode(''); await load(query)
    } catch (err) {
      setError(friendly(err))
    } finally {
      setBusy(false)
    }
  }

  async function saveEdit() {
    if (!editing) return
    const n = editing.name.trim(), cc = editing.code.trim()
    if (n.length < MIN_NAME) { setError(`Name must be at least ${MIN_NAME} characters.`); return }
    if (!cc) { setError('Code cannot be empty.'); return }
    setBusy(true); setError(null); setNotice(null)
    const { error } = await supabase.from('consignees').update({ code: cc, name: n }).eq('id', editing.id)
    setBusy(false)
    if (error) { setError(friendly(error)); return }
    setList((l) => l.map((c) => (c.id === editing.id ? { ...c, code: cc, name: n } : c)))
    setEditing(null); setNotice('Saved.')
  }

  async function remove(c: Consignee) {
    if (!window.confirm(`Delete ${c.code} – ${c.name}?`)) return
    setBusy(true); setError(null); setNotice(null)
    const { error } = await supabase.from('consignees').delete().eq('id', c.id)
    setBusy(false)
    if (error) { setError(friendly(error)); return }
    setList((l) => l.filter((x) => x.id !== c.id))
    setTotal((t) => Math.max(0, t - 1))
    setNotice(`Deleted ${c.code}.`)
  }

  return (
    <AdminShell>
      <div className="ktc-glass" style={{ padding: 28, marginBottom: 18 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em' }}>Consignees</h1>
        <p className="ktc-label" style={{ marginTop: 6, marginBottom: 20 }}>
          Master list ({total}). Add one below, or import a CSV (name required; code optional &amp; auto-generated).
          Duplicate names/codes are rejected.
        </p>

        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ display: 'grid', gap: 6 }}>
            <label className="ktc-label" htmlFor="csv">Import CSV</label>
            <input id="csv" ref={fileRef} type="file" accept=".csv,text/csv" className="ktc-input"
              onChange={onFile} disabled={busy} style={{ padding: '9px 13px' }} />
          </div>
          <form onSubmit={addOne} style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
            <div style={{ display: 'grid', gap: 6 }}>
              <label className="ktc-label" htmlFor="name">Consignee name *</label>
              <input id="name" className="ktc-input" value={name} onChange={(e) => setName(e.target.value)} required minLength={MIN_NAME} style={{ width: 220 }} />
            </div>
            <div style={{ display: 'grid', gap: 6 }}>
              <label className="ktc-label" htmlFor="code">Code (optional)</label>
              <input id="code" className="ktc-input" value={code} onChange={(e) => setCode(e.target.value)} placeholder="auto" style={{ width: 130 }} />
            </div>
            <button className="ktc-btn" type="submit" disabled={busy} style={{ width: 'auto', padding: '11px 18px' }}>Add consignee</button>
          </form>
        </div>

        {busy && <div className="ktc-label" style={{ marginTop: 12 }}>Working…</div>}
        {notice && <div className="ktc-label" style={{ marginTop: 12, fontSize: 13 }}>{notice}</div>}
        {error && <div style={{ marginTop: 12, color: 'var(--acc-2)', fontSize: 13 }}>{error}</div>}
      </div>

      <div className="ktc-glass" style={{ padding: 28 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, marginBottom: 14, flexWrap: 'wrap' }}>
          <h2 style={{ margin: 0, fontSize: 16, fontWeight: 600 }}>
            List {query ? `(${total} match${total === 1 ? '' : 'es'})` : total > list.length ? `(first ${list.length} of ${total})` : ''}
          </h2>
          <input className="ktc-input" placeholder="Search code or name…" value={query}
            onChange={(e) => setQuery(e.target.value)} style={{ width: 260 }} />
        </div>

        {loading ? <span className="ktc-label">Loading…</span> : list.length === 0 ? (
          <div className="ktc-label" style={{ fontSize: 14 }}>{query ? 'No matches.' : 'No consignees yet — add or import above.'}</div>
        ) : (
          <div style={{ display: 'grid', gap: 4 }}>
            {list.map((c) => (
              <div key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 0', borderBottom: '1px solid hsl(var(--line-soft))' }}>
                {editing?.id === c.id ? (
                  <>
                    <input className="ktc-input" value={editing.code} onChange={(e) => setEditing({ ...editing, code: e.target.value })} style={{ width: 120, padding: '6px 10px' }} />
                    <input className="ktc-input" value={editing.name} onChange={(e) => setEditing({ ...editing, name: e.target.value })} style={{ flex: 1, padding: '6px 10px' }} />
                    <button className="ktc-link" disabled={busy} onClick={saveEdit} style={{ fontSize: 13, fontWeight: 600 }}>Save</button>
                    <button className="ktc-link" onClick={() => setEditing(null)} style={{ fontSize: 13 }}>Cancel</button>
                  </>
                ) : (
                  <>
                    <span style={{ flex: 1, fontSize: 14 }}><b>{c.code}</b> – {c.name}</span>
                    <button className="ktc-link" onClick={() => setEditing({ id: c.id, code: c.code, name: c.name })} style={{ fontSize: 13 }}>Edit</button>
                    <button className="ktc-link" disabled={busy} onClick={() => remove(c)} style={{ fontSize: 13, color: 'var(--acc-2)' }}>Delete</button>
                  </>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </AdminShell>
  )
}
