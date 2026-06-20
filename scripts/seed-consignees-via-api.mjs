// Seed consignees via the Supabase Management API database/query endpoint
// (HTTPS) — used when the Postgres pooler is unreachable. Reads the access token
// + project URL DIRECTLY from .env.local (ignores ambient shell vars, which can
// be stale). Codes auto-generate as CN-00001… from consignee_code_seq.
//
// Dry run (count + sequence only):   node scripts/seed-consignees-via-api.mjs "<file>"
// Perform the seed (reset + insert):  node scripts/seed-consignees-via-api.mjs "<file>" --go
import { readFileSync, existsSync } from 'node:fs'
import path from 'node:path'; import { fileURLToPath } from 'node:url'
import { readGrid } from './sheetGrid.mjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
// Parse .env.local directly into a map (do NOT use process.env — ambient vars
// like a stale SUPABASE_ACCESS_TOKEN would shadow the real value).
const env = {}
for (const f of ['.env.local']) {
  const p = path.join(root, f); if (!existsSync(p)) continue
  for (const line of readFileSync(p, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/); if (!m) continue
    let v = m[2].trim(); if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
    env[m[1]] = v
  }
}
const token = env.SUPABASE_ACCESS_TOKEN
const ref = new URL(env.VITE_SUPABASE_URL).host.split('.')[0]
if (!token || !ref) { console.error('Missing SUPABASE_ACCESS_TOKEN / VITE_SUPABASE_URL in .env.local'); process.exit(1) }

const argv = process.argv.slice(2)
const go = argv.includes('--go')
const file = argv.find((a) => !a.startsWith('--'))
if (!file) { console.error('Pass a CSV/XLSX path'); process.exit(1) }

async function runSql(query) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  })
  const text = await r.text()
  if (!r.ok) throw new Error(`mgmt query ${r.status}: ${text.slice(0, 300)}`)
  return text ? JSON.parse(text) : []
}

// --- read + clean the names ---
const grid = await readGrid(file)
const header = grid[0].map((h) => h.trim().toLowerCase())
const nameIdx = header.findIndex((h) =>
  h === 'name' || h === 'consignee' || h === 'customer' || h.includes('customer name') || h.includes('consignee name'))
if (nameIdx < 0) { console.error('No name column. Headers:', header.join(', ')); process.exit(1) }
const seen = new Set(); const names = []
for (const r of grid.slice(1)) {
  const name = (r[nameIdx] ?? '').trim()
  if (!name || /^(grand\s+)?total$/i.test(name)) continue
  const key = name.toLowerCase(); if (seen.has(key)) continue
  seen.add(key); names.push(name)
}
console.log(`file: ${grid.length - 1} rows · unique names to seed: ${names.length}`)

// --- inspect current state ---
const cnt = (await runSql('select count(*)::int as n from public.consignees'))[0].n
const seq = (await runSql("select last_value, is_called from public.consignee_code_seq"))[0]
console.log(`current consignees: ${cnt} · seq last_value=${seq.last_value} is_called=${seq.is_called}`)

if (!go) { console.log('\nDRY RUN — re-run with --go to reset the sequence and insert.'); process.exit(0) }

if (cnt > 0) { console.error(`\nABORT: ${cnt} consignees already exist — refusing to reset/seed over existing data.`); process.exit(1) }

// --- reset sequence so codes start at CN-00001, then bulk insert in file order ---
await runSql('alter sequence public.consignee_code_seq restart with 1')
console.log('✓ consignee_code_seq reset to 1')

const esc = (s) => "'" + s.replace(/'/g, "''") + "'"
let inserted = 0
for (let i = 0; i < names.length; i += 500) {
  const chunk = names.slice(i, i + 500)
  const values = chunk.map((n) => `(${esc(n)})`).join(',')
  const res = await runSql(`insert into public.consignees (name) values ${values} on conflict do nothing returning 1`)
  inserted += Array.isArray(res) ? res.length : 0
  console.log(`  batch ${i / 500 + 1}: +${Array.isArray(res) ? res.length : 0} (total ${inserted})`)
}

const total = (await runSql('select count(*)::int as n from public.consignees'))[0].n
const first = await runSql("select code, name from public.consignees order by code asc limit 3")
const last = await runSql("select code, name from public.consignees order by code desc limit 3")
console.log(`\ninserted: ${inserted} · total consignees now: ${total}`)
console.log('first 3:', first.map((r) => `${r.code} ${r.name}`).join(' | '))
console.log('last 3 :', last.map((r) => `${r.code} ${r.name}`).join(' | '))
