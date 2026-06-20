// Import consignees from a CSV/XLSX into public.consignees. Codes auto-generate
// as CN-00001, CN-00002, … via the consignee_code_seq DB default (migration 0006).
// Detects a name column ("name"/"consignee"/"customer"…) and an optional "code"
// column. Dedups by name (case-insensitive) within the file AND against existing
// rows, so it's safe to re-run. Skips analytics-export "Total" summary rows.
//
// DATABASE_URL is read from process.env or the gitignored .env.local — never put
// the connection string on the command line or in git.
//
// Usage:
//   node scripts/import-consignees.mjs "C:/path/file.xlsx"
//   node scripts/import-consignees.mjs "C:/path/file.xlsx" --reset-seq
//       (clean slate: restart codes at CN-00001; REFUSES if any consignees exist)
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import pg from 'pg'
import { readGrid } from './sheetGrid.mjs'

// Load env from gitignored files (no secret on the CLI). Only fills unset vars.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
for (const f of ['.env.local', '.env.migrate', '.env']) {
  const p = path.join(root, f)
  if (!existsSync(p)) continue
  for (const line of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/)
    if (!m || process.env[m[1]] !== undefined) continue
    let v = m[2].trim()
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
    process.env[m[1]] = v
  }
}

const argv = process.argv.slice(2)
const resetSeq = argv.includes('--reset-seq')
const file = argv.find((a) => !a.startsWith('--'))
if (!file) { console.error('Pass a CSV/XLSX path'); process.exit(1) }
const url = process.env.DATABASE_URL
if (!url) { console.error('No DATABASE_URL (set it in .env.local)'); process.exit(1) }

const grid = await readGrid(file)
const header = grid[0].map((h) => h.trim().toLowerCase())
const nameIdx = header.findIndex((h) =>
  h === 'name' || h === 'consignee' || h === 'customer' || h.includes('customer name') || h.includes('consignee name'))
const codeIdx = header.findIndex((h) => h === 'code')
if (nameIdx < 0) { console.error('Could not find a name column. Headers:', header.join(', ')); process.exit(1) }

// Build deduped rows (case-insensitive by name); skip blanks + summary rows.
const seen = new Set()
const rows = []
for (const r of grid.slice(1)) {
  const name = (r[nameIdx] ?? '').trim()
  if (!name) continue
  if (/^(grand\s+)?total$/i.test(name)) continue // analytics-export summary row
  const key = name.toLowerCase()
  if (seen.has(key)) continue
  seen.add(key)
  rows.push({ name, code: codeIdx >= 0 ? (r[codeIdx] ?? '').trim() : '' })
}

// Connect resiliently: prefer the transaction pooler (:6543, high capacity) for
// this one-off, fall back to the session pooler (:5432). A connect timeout means
// a contended/stalled pooler fails fast instead of leaving a zombie connection.
async function openClient(connStr) {
  const txn = connStr.replace(':5432', ':6543')
  const tries = txn !== connStr ? [['6543', txn], ['5432', connStr]] : [[new URL(connStr).port, connStr]]
  for (const [port, u] of tries) {
    const client = new pg.Client({ connectionString: u, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 20000 })
    try { await client.connect(); console.log('connected on :' + port); return client }
    catch (e) { console.log(':' + port + ' connect failed —', e.message) }
  }
  throw new Error('Could not connect to the database on either pooler port.')
}
const c = await openClient(url)
try {
  const existing = await c.query('select lower(name) as n from public.consignees')
  const have = new Set(existing.rows.map((x) => x.n))

  if (resetSeq) {
    if (have.size > 0) {
      console.error(`Refusing --reset-seq: ${have.size} consignees already exist (resetting would risk code collisions). Aborting.`)
      process.exit(1)
    }
    await c.query('alter sequence public.consignee_code_seq restart with 1')
    console.log('✓ consignee_code_seq reset to 1 (table empty) — codes start at CN-00001')
  }

  const fresh = rows.filter((r) => !have.has(r.name.toLowerCase()))
  console.log(`file unique: ${rows.length} · already present: ${rows.length - fresh.length} · to insert: ${fresh.length}`)

  let inserted = 0
  for (let i = 0; i < fresh.length; i += 500) {
    const chunk = fresh.slice(i, i + 500)
    const withCode = chunk.filter((r) => r.code)
    const noCode = chunk.filter((r) => !r.code)
    if (noCode.length) {
      const vals = noCode.map((_, k) => `($${k + 1})`).join(',')
      const res = await c.query(`insert into public.consignees (name) values ${vals} on conflict do nothing`, noCode.map((r) => r.name))
      inserted += res.rowCount
    }
    if (withCode.length) {
      const vals = withCode.map((_, k) => `($${k * 2 + 1}, $${k * 2 + 2})`).join(',')
      const params = withCode.flatMap((r) => [r.code, r.name])
      const res = await c.query(`insert into public.consignees (code, name) values ${vals} on conflict (code) do update set name = excluded.name`, params)
      inserted += res.rowCount
    }
  }
  const total = await c.query('select count(*)::int n from public.consignees')
  console.log(`inserted: ${inserted} · total consignees now: ${total.rows[0].n}`)
  const first = await c.query('select code, name from public.consignees order by code asc limit 3')
  const last = await c.query('select code, name from public.consignees order by code desc limit 3')
  console.log('first 3:', first.rows.map((r) => `${r.code} ${r.name}`).join(' | '))
  console.log('last 3 :', last.rows.map((r) => `${r.code} ${r.name}`).join(' | '))
} finally {
  await c.end()
}
