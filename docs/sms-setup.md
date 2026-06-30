# SMS notifications — setup & activation runbook

**Status: scaffold built + activation-safe** (2026-06-30). The plumbing ships with the app; **nothing sends a text until a gateway is connected and the matching notification channel is set to SMS/both** (Vault `sms_url`/`sms_secret` rows arm the transport; admin notification routing decides which events may text).

SMS is a 4th notification channel beside in-app + email + web-push. It is **selective**: only high-value customer notifications text the customer (a text is costlier + more intrusive than a push).

## What's built

| Piece | File | Role |
|---|---|---|
| Transport | `supabase/functions/send-sms/index.ts` | POSTs the current SMSGate `/3rdparty/v1/messages` payload (`textMessage`, `phoneNumbers`) to the android-sms-gateway; gated by `x-sms-secret`. |
| Trigger | `supabase/migrations/0193_sms_notifications.sql` + `0231_sms_activation_safety.sql` | AFTER INSERT on `notifications` → maps whitelisted kinds to `notification_settings`; texts only when the admin channel is `sms`/`both`; respects `customers.sms_opt_out` + `ph_e164()`. |
| Deploy/config | `scripts/setup-sms.mjs` | Deploys the function, sets secrets, writes Vault only when gateway credentials exist; otherwise disarms Vault so SMS stays dormant. |

**Whitelisted kinds** (edit the `in (...)` list in 0193 to change): `on_hold`, `rejected`, `completed`, `payment_confirmed`, `payment_rejected`, `release_payable`, `release_on_hold`, `release_rejected`, `release_released` — the "you must act" + "it's decided / ready" moments.

## Activation (owner)

1. **Phone gateway** — on a **dedicated Android phone + SIM** (kept charged + online), install **"SMS Gateway for Android"** (sms-gate.app). Pick **Cloud** mode (free relay `https://api.sms-gate.app`, no registration) for the serverless backend; copy its Basic-auth **user/pass**.
2. **`.env.local`** — add `SMS_GATEWAY_USER` + `SMS_GATEWAY_PASS` (and optionally `SMS_GATEWAY_URL`). Ensure a **personal** `SUPABASE_ACCESS_TOKEN` (`sbp_…`) is present (the same token the other Management-API scripts need).
3. **Run** `node scripts/setup-sms.mjs` — deploys the function. With gateway creds present, it arms Vault; without them, it disarms Vault and stays dormant.
4. **Smoke test** — the script prints a `curl` one-liner; send yourself a text.
5. **Route events** — in Admin → Settings → Operations → Notifications, set the desired rows to `SMS` or `Email + SMS`.

## Cost / reliability

- **Free software**; you pay only the carrier SMS rate (≈ free on a bundled/unli SIM). One phone = a single point of failure — keep it powered + online; a consumer SIM does tens–low-hundreds/hour before carrier throttling, so this is for **transactional** texts, not blasts.
- **Graduating later** to a managed gateway (Semaphore PH ~₱0.50/SMS with a sender ID, or Twilio) = change `SMS_GATEWAY_*` + the POST body in `send-sms`; the trigger + auth gate are unchanged.

## Activation notes

- **Customer opt-out toggle** is live in `/account` as "SMS updates" and calls `set_sms_opt_out`.
- **Staff SMS** — staff use synthetic `@ktc-staff.local` accounts with no stored mobile; this scaffold is customer-only. Add a staff-phone column + a `staff_notifications` trigger if staff SMS is ever wanted.
