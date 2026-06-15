// Shipping lines KTC carries + the terminal charges per-line rules can target.
// Shared by the Rate Calculator and the admin Settings rules editor so the two
// never drift. MCC is Maersk's domestic feeder arm, so the trade route is
// derived from the line (only MCC is domestic).

export type Origin = 'domestic' | 'foreign'

export const SHIPPING_LINES: { code: string; label: string; origin: Origin }[] = [
  { code: 'MAERSK', label: 'Maersk', origin: 'foreign' },
  { code: 'MCC', label: 'MCC', origin: 'domestic' },
  { code: 'EVERGREEN', label: 'Evergreen', origin: 'foreign' },
  { code: 'SITC', label: 'SITC', origin: 'foreign' },
  { code: 'MSC', label: 'MSC', origin: 'foreign' },
  { code: 'CMA-CGM', label: 'CMA-CGM', origin: 'foreign' },
]

// Terminal charges a per-line rule can waive / discount / surcharge.
export const TERMINAL_CHARGE_SERVICES: { key: string; label: string }[] = [
  { key: 'arrastre', label: 'Arrastre' },
  { key: 'wharfage', label: 'Wharfage' },
  { key: 'lolo', label: 'LoLo' },
  { key: 'weighing', label: 'Weighing scale' },
  { key: 'storage', label: 'Storage' },
]

export const CHARGE_RULE_ACTIONS: { key: string; label: string; needsValue: boolean }[] = [
  { key: 'waive', label: 'Waive (exclude)', needsValue: false },
  { key: 'discount_pct', label: 'Discount %', needsValue: true },
  { key: 'discount_amt', label: 'Discount ₱ / container', needsValue: true },
  { key: 'surcharge_amt', label: 'Surcharge ₱ / container', needsValue: true },
]

// Normalise a line name/code for loose matching (schedule stores display names
// like "Maersk"/"CMA CGM"; rules + the calculator key on the CODE).
export const normLine = (s: string | null | undefined) => (s ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '')
