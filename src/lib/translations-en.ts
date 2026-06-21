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
    "Your account is suspended. Please message KTC customer service for help.",
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
    "Two-factor is turned off. Your account uses a password only now — we recommend setting it up again.",
  "Resolve holds & info requests":
    "Clear holds and info requests",
  "Per-shipping-line charge rules":
    "Charge rules per shipping line",
  "A KTC admin is verifying your account. You can continue filing job orders, but they’re held until you’re verified. For more information, contact customer service at":
    "A KTC admin is checking your account. You can keep filing job orders, but they stay held until you're verified. For more details, contact customer service at",
  "A KTC admin is verifying your account. Orders stay held until you’re verified.":
    "A KTC admin is checking your account. Your orders stay held until you're verified.",
  "All registered customer accounts and their status. Approve/reject pending ones under Approvals; suspend or reactivate approved accounts here.":
    "All customer accounts and their status. Approve or reject the pending ones under Approvals; suspend or reactivate approved accounts here.",
  "Adds a 6-digit code from an authenticator app (Google Authenticator, Authy, 1Password…) to your sign-in. Once enabled it's enforced":
    "Adds a 6-digit code from an authenticator app (Google Authenticator, Authy, 1Password…) to your sign-in. Once on, it's always required",
  "Archives every completed order that has a Service Invoice number (= paid). Also runs automatically every Monday.":
    "Files away every completed order that has a Service Invoice number (= paid). Also runs by itself every Monday.",
  "Background jobs, outgoing emails / BOC mirror calls, and client errors. The hourly watchdog emails the owner on failures.":
    "Background jobs, outgoing emails / BOC mirror calls, and app errors. The hourly watchdog emails the owner when something fails.",
  "Bank account + QRPH QR shown when a customer pays online. Online payments (GCash / Maya / banks) all route through the QR. Leave fields blank to hide them.":
    "Bank account + QRPH QR shown when a customer pays online. All online payments (GCash / Maya / banks) go through the QR. Leave fields blank to hide them.",
  "Can’t be processed until you pass final verification — upload your valid ID, then a KTC admin verifies your account and it’s sent automatically.":
    "Can't be processed until you pass final verification — upload your valid ID, then a KTC admin verifies your account and it's sent on its own.",
  "Choose the vessel & voyage from the current schedule. Not listed yet? Tick \"vessel not listed\" and type it — operations will match it to the call.":
    "Pick the vessel & voyage from the current schedule. Not listed yet? Tick \"vessel not listed\" and type it — operations will match it to the right call.",
  "Consignees added but not yet approved. Tap to review and approve them so they're selectable when customers file.":
    "Consignees added but not yet approved. Tap to review and approve them so customers can pick them when filing.",
  "Current vessel calls at KTC. Last free day is the last day of free storage (finish discharging + the line's free-days); after it, storage charges apply. Schedule is maintained by KTC operations — for reference only.":
    "Current vessels at KTC. Last Free Day is the last day of free storage (finish discharging + the line's free-days); after that, storage charges apply. KTC operations keeps the schedule — for reference only.",
  "Edit or update your personal details anytime. Changing your legal name needs re-verification by a KTC admin (since it's matched to your ID).":
    "Edit or update your details anytime. If you change your legal name, a KTC admin has to re-verify it (since it must match your ID).",
  "Every order you file shows here with its live status and serving number. Open one to \"View charges & pay\" (upload your deposit slip) and to Print the A6 slip once it's approved. The \"Now serving\" board up top helps you time your trip to the terminal.":
    "Every order you file shows here with its live status and serving number. Open one to \"View charges & pay\" (upload your deposit slip) and to Print the A6 slip once it's approved. The \"Now serving\" board up top helps you plan when to go to the terminal.",
  "File Job Orders for container terminal services from anywhere, anytime. No more queueing at the office. Here's a quick look around.":
    "File Job Orders for container terminal services from anywhere, anytime. No more lining up at the office. Here's a quick tour.",
  "If an order needs port-services moves (DEA / inspection), use Assess RPS on its card to record the moves — they bill per move on top of the base. Most orders need none.":
    "If an order needs port-services moves (DEA / inspection), use Assess RPS on its card to record the moves — they're billed per move on top of the base. Most orders need none.",
  "Add each container number and the service it needs — or Bulk paste a whole list at once. Then submit; you'll get a serving number per service line.":
    "Add each container number and the service it needs — or Bulk paste a whole list at once. Then submit; you'll get a serving number for each service line.",
  "Each line becomes a container row with the selected service — you can change any row's service afterward. Duplicates are skipped.":
    "Each line becomes a container row with the chosen service — you can change any row's service later. Duplicates are skipped.",
  "Days since completion without a Service Invoice on file":
    "Days since it finished with no Service Invoice on file",
  "Cannot approve — no valid ID on file yet. Ask the customer to upload one first.":
    "Can't approve — no valid ID on file yet. Ask the customer to upload one first.",
  "is computed (finish discharging + the line's import free-days); a call drops off once its last free day passes. Free-days per line are set by admin in Settings.":
    "is worked out (finish discharging + the line's import free-days); a call drops off once its Last Free Day passes. Free-days per line are set by admin in Settings.",
}
