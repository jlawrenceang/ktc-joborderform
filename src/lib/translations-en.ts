// Simplified-English overrides, keyed by the original English source string.
//
// The English source string is the t() KEY (see i18n.tsx). Some of those source
// strings are written above a plain-reading level — long, formal, or jargon-y.
// This map rewrites them into shorter, plainer English (≈ Grade-6, friendly) WITHOUT
// changing any component: the resolver applies enSimple[key] ?? key in English mode,
// and uses it as the fallback under Tagalog (tl[key] ?? enSimple[key] ?? key).
//
// Rules (must hold for every entry):
//  • The KEY must match the current English source string EXACTLY (a mismatch is a
//    harmless no-op — it simply falls back to the original).
//  • Every {placeholder} in the key must appear, spelled identically, in the value.
//  • Keep industry/UI terms in English (Job Order, container, X-ray, DEA, OOG,
//    consignee, voyage, vessel, RPS, VAT, OR, invoice, payment, upload, password,
//    account, etc.). Keep any leading glyphs (✓ ↻ ← → +) and trailing spaces.
//  • Only add an entry when the plainer English actually differs — otherwise omit it.

export const enSimple: Record<string, string> = {
  "Your account has been suspended. Please contact KTC customer service for assistance.":
    "Your account is suspended. Message KTC customer service for help.",
  "This document is confidential and may not be printed, saved, or reproduced.":
    "This is confidential. You can't print, save, or copy it.",
  "Confidential — for viewing only. Printing, saving and copying are disabled.":
    "Confidential — view only. Print, save, and copy are turned off.",
  "Internal KTC staff with admin access. Managed separately from brokers.":
    "KTC staff with admin access. Managed apart from customers.",
  "Other services (RPS, equipment rental, stripping) are quoted per request — ask KTC.":
    "Other services (RPS, equipment rental, stripping) are priced per request — ask KTC.",
  "What each staff role may do. Owner-only — enforced server-side (RLS + RPCs), the UI just mirrors it.":
    "What each staff role can do. Owner only — set on the server; this screen just shows it.",
  "Blocked privilege-escalation attempt":
    "Blocked an attempt to gain higher access",
  "Two-factor authentication removed. Your account is back to password-only — consider re-enrolling.":
    "Two-factor turned off. Your account uses password only now — best to set it up again.",
  "Resolve holds & info requests":
    "Clear holds and info requests",
  "Per-shipping-line charge rules":
    "Charge rules per shipping line",
}
