import { createContext, useCallback, useContext, useState, type ReactNode } from 'react'
import { tl } from './translations'

// Lightweight, dependency-free i18n. English is the source of truth and the
// translation KEY: components wrap user-facing strings with t('English text'),
// and the Tagalog dictionary (translations.ts) maps that English string to its
// Tagalog. Anything not in the dictionary falls back to English automatically,
// so the app is always shippable mid-translation.
//
// Default is English; the choice is remembered per browser (localStorage).
// Interpolation: t('Hello {name}', { name }) replaces {name} in either language.

export type Lang = 'en' | 'tl'
const KEY = 'ktc_lang'
const CHOSEN = 'ktc_lang_set' // set once the user has made an explicit choice

export type TFunc = (en: string, vars?: Record<string, string | number>) => string

interface I18nCtx {
  lang: Lang
  setLang: (l: Lang) => void
  // True once the user has explicitly picked a language (via the first-run
  // chooser or the nav toggle). Drives the one-time language prompt and gates
  // the first-run tour until a language is set.
  langChosen: boolean
  t: TFunc
}

const Ctx = createContext<I18nCtx>({ lang: 'en', setLang: () => {}, langChosen: false, t: (s) => s })

export function useT() { return useContext(Ctx) }

function interpolate(s: string, vars?: Record<string, string | number>): string {
  if (!vars) return s
  return s.replace(/\{(\w+)\}/g, (_, k) => (k in vars ? String(vars[k]) : `{${k}}`))
}

function initialLang(): Lang {
  try {
    const v = localStorage.getItem(KEY)
    return v === 'tl' ? 'tl' : 'en'
  } catch {
    return 'en'
  }
}
function initialChosen(): boolean {
  try { return localStorage.getItem(CHOSEN) === '1' } catch { return false }
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(initialLang)
  const [langChosen, setChosen] = useState<boolean>(initialChosen)
  const setLang = useCallback((l: Lang) => {
    try { localStorage.setItem(KEY, l); localStorage.setItem(CHOSEN, '1') } catch { /* ignore */ }
    setLangState(l)
    setChosen(true)
  }, [])
  const t = useCallback<TFunc>((en, vars) => {
    const out = lang === 'tl' ? (tl[en] ?? en) : en
    return interpolate(out, vars)
  }, [lang])
  return <Ctx.Provider value={{ lang, setLang, langChosen, t }}>{children}</Ctx.Provider>
}
