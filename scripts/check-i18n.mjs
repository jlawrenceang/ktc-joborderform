// i18n integrity check: every translation/override VALUE must carry exactly the
// same {placeholders} as its English KEY (a dropped/renamed {var} silently breaks
// the message). Run after editing src/lib/translations.ts / translations-en.ts.
//
// Usage: node scripts/check-i18n.mjs   (exit 1 on any mismatch)
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const files = ['src/lib/translations.ts', 'src/lib/translations-en.ts']

// "key": "value" pairs (double-quoted, escaped chars allowed, key/value may span a newline).
const PAIR = /"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"/g
const tokens = (s) => (s.match(/\{(\w+)\}/g) ?? []).slice().sort()
const eq = (a, b) => a.length === b.length && a.every((x, i) => x === b[i])

let problems = 0
let checked = 0
for (const rel of files) {
  let text
  try { text = readFileSync(path.join(root, rel), 'utf8') } catch { continue }
  // Drop // line comments so header prose isn't mistaken for entries.
  const body = text.replace(/^\s*\/\/.*$/gm, '')
  let m
  while ((m = PAIR.exec(body)) !== null) {
    const [, key, val] = m
    const kt = tokens(key)
    const vt = tokens(val)
    checked++
    if (!eq(kt, vt)) {
      problems++
      console.error(`✗ ${rel}\n    key   {${kt.join(',')}}: ${key.slice(0, 70)}\n    value {${vt.join(',')}}: ${val.slice(0, 70)}`)
    }
  }
}
console.log(`\nchecked ${checked} entries — ${problems} placeholder mismatch(es)`)
process.exit(problems ? 1 : 0)
