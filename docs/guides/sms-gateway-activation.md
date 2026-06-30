# Activating SMS Notifications — Owner Guide

A complete, do-it-yourself guide to turning on text-message (SMS) alerts for the KTC Online Portal while your developer is offline.

**Good news up front:** the hard part is already built and shipped. The portal already knows *when* to send a text and *who* to send it to — it has been sitting dormant, waiting for one thing: a phone to actually send the texts from. This guide connects that phone and flips the switch. You do **not** need to touch any app code to go live.

**Roughly how long:** 30–45 minutes, most of it on the phone setup.

> Throughout this guide, anything you type into your Claude Code session is shown after a `! ` prefix (that is how you run a real command from inside Claude Code). You can also just paste these into a normal PowerShell window — either works.

---

## 1. What this gives KTC, and when a text fires

A text message reaches a customer even when they never open the app or their email. It is best for **short, high-value, "you need to know this now" moments**. The portal is already set to text a customer **only** on these events (and nothing else):

- **Job Order put on hold** (`on_hold`)
- **Job Order rejected** (`rejected`)
- **Job Order completed** (`completed`)
- **Payment confirmed** (`payment_confirmed`)
- **Payment rejected** (`payment_rejected`)
- **Release bill ready to pay** (`release_payable`)
- **Release put on hold** (`release_on_hold`)
- **Release rejected** (`release_rejected`)
- **Release cleared / container released** (`release_released`)

Every other notification (general bulletins, minor status pings, internal staff alerts) does **not** text anyone. This is deliberate — a text costs a little and is more intrusive than an in-app or email notice, so it is reserved for the moments that matter.

**When to keep using push / email instead of SMS:**

- **Bulk or marketing messages** — never over this gateway (one phone/SIM gets throttled by the carrier; see Section 8).
- **Long or detailed messages** — email. A text is capped at ~320 characters.
- **Anything a customer can read later at their leisure** — in-app notification or email.

Think of SMS as the "tap on the shoulder" channel, layered *on top of* the push and email the portal already sends. It does not replace them.

---

## 2. Hardware and SIM preparation

You need **one dedicated Android phone** that becomes KTC's SMS sender. It does not need to be fancy.

1. **Phone:** any reasonably modern Android phone (Android 8 or newer). It can be an old spare. iPhones cannot do this — it must be Android.
2. **SIM / plan:** a SIM card with an SMS allowance. A prepaid SIM with a bundled-texts promo (Globe, Smart, DITO, etc.) is ideal because each text is then effectively free. A plan with unlimited or large texts-to-all-networks works best so messages reach customers on any network.
3. **Keep it alive — this phone is the single point of failure:**
   - Plug it into a charger permanently and leave it on. Treat it like a small appliance, not a phone you carry around.
   - Keep it connected to Wi-Fi (and leave mobile data on as a backup).
   - Turn **off** any battery-saver or "deep sleep" / "app standby" feature for the gateway app, or the phone may stop sending while asleep.
   - Put it somewhere safe in the office with good signal. If this phone goes offline, texts simply stop sending (the rest of the portal keeps working normally — nothing breaks, customers just won't get the text).

---

## 3. Install and configure the SMS Gateway app on the phone

The app is **"SMS Gateway for Android"** from **sms-gate.app** (free, open-source). It turns the phone into a tiny SMS web service the portal can call.

1. On the dedicated phone, open a browser and go to **https://sms-gate.app** — follow its link to install the app (or find "SMS Gateway for Android" by capcom6). Install it.
2. Open the app and **grant it permission to send SMS** when asked.
3. **Choose the mode.** The app offers a few. For KTC, choose **Cloud mode** (sometimes labelled "Cloud Server" — it uses `https://api.sms-gate.app`).

   **Why Cloud mode (recommended):** the portal's sender runs on Supabase's servers in the cloud, *not* inside your office network. Cloud mode lets those servers reach the phone through the free public relay without any router/firewall/IP setup. It is the simplest reliable option and the one the portal already defaults to.

   **The tradeoff:** in Cloud mode your messages pass through the free public relay (it has a fair-use limit and a 24-hour queue cap — fine for KTC's low volume). The alternative, **Local mode**, keeps everything inside your office network but would require your developer to expose the phone to the internet safely — more work, more risk, and not needed now. Stick with Cloud.
4. After enabling Cloud mode, the app shows you **login credentials** — a **username** and a **password** (Basic-auth). Some versions show them on the main/home screen or under a "Cloud" or "Server"/"Settings" section. **Write these two values down exactly** (they are case-sensitive). These are the only two things you carry from the phone to the next step.
5. Send yourself a test text *from within the app* if it offers that option, just to confirm the SIM can actually send. If that fails, the SIM/plan is the problem — fix it before going further.

> You will use the username as **`SMS_GATEWAY_USER`** and the password as **`SMS_GATEWAY_PASS`** in Section 4. That is the entire handoff from phone to portal.

---

## 4. Set the secrets (what the portal needs to know)

The portal's text sender is an "Edge Function" called **`send-sms`**. It reads exactly four secret settings. Here is each one, what it is, and where the value comes from:

| Secret name | What it is | Where the value comes from |
|---|---|---|
| `SMS_GATEWAY_USER` | The phone app's username | From the phone app (Section 3, step 4) |
| `SMS_GATEWAY_PASS` | The phone app's password | From the phone app (Section 3, step 4) |
| `SMS_GATEWAY_URL` | The gateway address | Leave it **unset** — the function defaults to the free cloud relay `https://api.sms-gate.app`. Only set this if you self-host later. |
| `SMS_SECRET` | A private password that lets *only* the portal call the sender (blocks strangers) | Generated automatically for you — you do not invent it. |

(These names are read verbatim by the function at `supabase/functions/send-sms/index.ts`, lines 22–25.)

**The easy way — let the setup script do all of it.** KTC ships a one-command setup script (`scripts/setup-sms.mjs`) that sets these secrets, deploys the function, *and* arms the database — all at once. You do not have to set secrets by hand. You only need to put your two phone credentials into the project's private settings file first:

1. Open the file **`.env.local`** in the project folder (`C:\Users\jlawr\github\ktc-portal\.env.local`) in a text editor. This file is private and never leaves your machine.
2. Add these two lines at the bottom (paste your real values from the phone app):

   ```
   SMS_GATEWAY_USER=paste-the-username-here
   SMS_GATEWAY_PASS=paste-the-password-here
   ```

3. Save the file. That is all the editing you do.

The three other things the script needs — `SUPABASE_ACCESS_TOKEN`, `VITE_SUPABASE_URL`, and `DATABASE_URL` — are **already in your `.env.local`** from earlier setup, so you do not add them. (If the script ever complains one is missing, that is the file to check.)

> **Alternative — the dashboard click-path (only if you prefer not to use the file/script):** You can set secrets by hand in the Supabase dashboard. Go to **https://supabase.com/dashboard** → select the **KTC project** (`mdlnfhyylvapzdubhyic`) → left sidebar **Edge Functions** → **Secrets** (or **Project Settings → Edge Functions → Secrets** / **Manage secrets**) → **Add new secret** → add `SMS_GATEWAY_USER`, then `SMS_GATEWAY_PASS`, and `SMS_SECRET` (for the last one, type any long random string and keep a copy). **Important:** if you set secrets by hand this way, you must *also* arm the database with the matching `SMS_SECRET` — the setup script does that for you automatically, by hand it is fiddly. **So the script in Section 5 is strongly recommended over the dashboard.**

> **Equivalent CLI command (for reference):** the script ultimately does the same as `supabase secrets set SMS_GATEWAY_USER=... SMS_GATEWAY_PASS=...`. You do **not** need to run this — the script handles it — but that is the underlying command if your developer asks.

---

## 5. Deploy the sender and arm the database — one command

Make sure you have done Section 4 (added the two lines to `.env.local`). Then, in your Claude Code session (or a PowerShell window in the project folder), run:

```
! node scripts/setup-sms.mjs
```

This single command does three things in order:

1. **Deploys** the `send-sms` function to the live KTC project.
2. **Sets** the secrets (your two gateway credentials + the auto-generated `SMS_SECRET`).
3. **Arms the database** — writes the two private "Vault" rows (`sms_url`, `sms_secret`) that the notification trigger checks before sending. Until these exist, the portal stays silent; once they exist, texts start flowing for the events in Section 1.

When it finishes you will see lines ending in:

```
✓ send-sms function deployed
✓ secrets set (...)
✓ vault updated — the notifications SMS trigger (migration 0193) is now armed
  Manual test:  curl -X POST https://mdlnfhyylvapzdubhyic.supabase.co/functions/v1/send-sms -H "x-sms-secret: <a long secret>" ...
```

**Copy that whole "Manual test" line** — you will use it in Section 6. The `<a long secret>` in it is your real `SMS_SECRET`.

**Important safety notes:**

- The live KTC project is **`mdlnfhyylvapzdubhyic`**. The script reads it from your `.env.local`, so it targets the right one automatically.
- **Do NOT** ask Claude to use its built-in Supabase tools (the `mcp__supabase__*` tools) for any of this. Those are pointed at a *different* project (jta-sys) and would touch the wrong database. Always use the `node scripts/setup-sms.mjs` command shown here, which targets KTC's project correctly.
- If the script errors with "Need SUPABASE_ACCESS_TOKEN...", your access token may have expired. Tell your developer; this is a known occasional gotcha. The fix is refreshing that one value in `.env.local`.

---

## 6. Send yourself ONE test text (without spamming any customer)

This proves the whole chain works — portal → phone → carrier → a real handset — using **your own** number only.

1. Take the **"Manual test" command** the script printed in Section 5. It already contains your real secret. It looks like this (yours will have the real secret filled in):

   ```
   curl -X POST https://mdlnfhyylvapzdubhyic.supabase.co/functions/v1/send-sms -H "x-sms-secret: YOUR_SECRET" -H "Content-Type: application/json" -d '{"to":["+639XXXXXXXXX"],"message":"KTC test"}'
   ```

2. Replace **`+639XXXXXXXXX`** with **your own** mobile number in international format: `+63` then your number without the leading 0. Example: `0917 123 4567` becomes `+639171234567`.

3. Run it from your Claude Code session by putting `! ` in front, or from a PowerShell window. On Windows, use **`curl.exe`** (with the `.exe`) so Windows uses the real curl:

   ```
   ! curl.exe -X POST https://mdlnfhyylvapzdubhyic.supabase.co/functions/v1/send-sms -H "x-sms-secret: YOUR_SECRET" -H "Content-Type: application/json" -d "{\"to\":[\"+639171234567\"],\"message\":\"KTC test\"}"
   ```

   (If the quotes give you trouble in PowerShell, the simplest fix is to paste the command into your Claude Code session with `! ` in front and let it run — it handles quoting.)

4. **What success looks like:** within a few seconds to a minute, **your phone gets a text** reading "KTC test". The command's reply will be a short JSON acknowledgement from the gateway. 

5. **If no text arrives, read the reply:**
   - `"forbidden"` → the secret in your command does not match. Re-copy the exact line the script printed.
   - `"gateway not configured ..."` → the phone username/password did not get set. Re-check Section 4 step 2, then re-run `! node scripts/setup-sms.mjs`.
   - A gateway error / nothing → the phone may be offline, asleep, out of signal, or out of SMS allowance. Check the phone (Section 2).

Because you only ever put **your own number** in the test, no customer is ever contacted during testing. Send a couple of tests to your own number until you are happy. **Once your own phone receives the test, the system is live** — the next time a real customer's order hits one of the Section 1 events, they will get a text automatically.

---

## 7. (Developer step — OPTIONAL — the owner can skip this)

**You do not need to wire anything into the app.** This is the part that surprises people: unlike a normal feature, SMS was built to fire *automatically from the database*. Whenever the portal saves a customer notification of one of the Section 1 types, a database trigger (`sms_on_notification`, added by migration `0193_sms_notifications.sql`) instantly and automatically calls the `send-sms` function. There is **no place in the app code** that needs a "send SMS" line added — and a search of the app (`src/`) confirms there are zero call sites, by design. The notification system the app already uses *is* the trigger point.

So the only reason a developer would ever touch code here is to **change which events text the customer**. That lives in exactly one place:

- **File:** `supabase/migrations/0193_sms_notifications.sql`
- **Function:** `public.sms_on_notification()`
- **The line that decides:** the whitelist near the top of that function —

  ```sql
  if new.kind not in ('on_hold','rejected','completed','payment_confirmed','payment_rejected',
                      'release_payable','release_on_hold','release_rejected','release_released') then
    return new;   -- not a texting event → do nothing
  end if;
  ```

To add or remove an event, a developer writes a **new** migration (forward-only — never edits the old file) that runs `create or replace function public.sms_on_notification() ...` with the adjusted list. Example, to also text on a new `vessel_arrived` event, the new migration's list would read `... ,'release_released','vessel_arrived')`. This is a database change, applied by your developer with the project's migration process — **not** something to do while they are offline. Leave the list as-is for go-live; it already covers the right moments.

**Bottom line for the owner:** Sections 1–6 are the entire activation. Section 7 is informational.

---

## 8. Cost, limits, failure, and the OFF switch

**Cost.** The software is free. You pay only your SIM's normal text rate — and with a bundled-texts prepaid SIM that is effectively zero. There is no per-message gateway fee.

**Volume limits (important).** This is **one phone with one SIM**. Carriers throttle a single number that sends too fast — expect a safe ceiling of *tens to low-hundreds of texts per hour* before the carrier slows or blocks it. KTC's transactional volume (a text per real order event) sits comfortably under this. **Never** use this channel for blasts or marketing — that would get the SIM flagged. Inside the phone app you can set per-minute / per-hour / per-day caps as a safety belt; consider setting a sane daily cap.

**Failure behaviour (reassuring).** If the phone is offline, asleep, or out of allowance, texts simply don't go out — **nothing else breaks**. The portal's notification save does not wait on the text (it is "fire-and-forget"), so orders, payments, and the app all keep working normally even if SMS is down. Customers still get their in-app and email notifications. So a dead SMS phone is a missing-text problem, never an outage.

**The customer opt-out (already built).** Any customer can turn their own texts off; the system has a per-customer `sms_opt_out` switch (migration 0193) and respects it automatically. You do not manage this.

**The kill switch — how to turn SMS OFF fast if it misbehaves.** There are two levels:

1. **Fastest, no code:** physically turn off or unplug the gateway phone, or close the app on it. Texts stop immediately because the sender has nothing to send through. This is the panic button — anyone in the office can do it.

2. **Cleanly disarm the whole channel (recommended if you want it off for a while):** remove the two "Vault" rows that arm the trigger. With them gone, the database trigger goes back to being a silent no-op — exactly the dormant state it shipped in — and the app is completely unaffected. Run this in your Claude Code session:

   ```
   ! node -e "const pg=require('pg');const fs=require('fs');const u=(fs.readFileSync('.env.local','utf8').match(/^DATABASE_URL=(.*)$/m)||[])[1];const c=new pg.Client({connectionString:u.trim(),ssl:{rejectUnauthorized:false}});c.connect().then(()=>c.query(\"delete from vault.secrets where name in ('sms_url','sms_secret')\")).then(r=>{console.log('SMS disarmed — rows removed:',r.rowCount);return c.end()})"
   ```

   To turn it **back on**, just run `! node scripts/setup-sms.mjs` again — it re-writes those rows.

**A note on a proper feature flag.** The portal already uses an on/off "feature flag" pattern elsewhere — for example customer emails are suspended-by-default behind a switch (`emails_enabled`). SMS does **not** yet have an equivalent single `sms_enabled` flag; today the on/off control is "are the Vault rows present" (the kill switch above) plus the per-customer opt-out. That is enough to launch and to stop it fast. **Recommend to your developer:** when they are back, ask them to add a simple `sms_enabled` setting mirroring the `emails_enabled` pattern, so toggling the whole channel is a one-line flip rather than deleting Vault rows. It is a small, nice-to-have hardening — not a blocker for going live.

---

## 9. Final checklist

Tick these off in order:

- [ ] **1.** Dedicated **Android** phone obtained, with a SIM that has a texts allowance.
- [ ] **2.** Phone is plugged in, on Wi-Fi, battery-saver disabled, kept in the office with good signal.
- [ ] **3.** "SMS Gateway for Android" app installed, SMS permission granted, **Cloud mode** enabled.
- [ ] **4.** Copied the app's **username** and **password**.
- [ ] **5.** Pasted them into `.env.local` as `SMS_GATEWAY_USER` and `SMS_GATEWAY_PASS`, file saved.
- [ ] **6.** Ran `! node scripts/setup-sms.mjs` and saw all three ✓ lines, including "vault updated ... trigger now armed".
- [ ] **7.** Copied the printed "Manual test" command.
- [ ] **8.** Sent a test text to **my own** number and **received it** on a real handset.
- [ ] **9.** Confirmed the test reply was not "forbidden" or "gateway not configured".
- [ ] **10.** Know the OFF switch: unplug the phone (instant) or run the disarm command (Section 8).
- [ ] **11.** Left the event list in Section 7 unchanged (developer-only).

When boxes 1–9 are ticked, SMS notifications are **live**. The next real order/payment/release event in the list will text the customer automatically. Nothing further is required from you.

---

*Reference (for the returning developer): function `supabase/functions/send-sms/index.ts`; migration `supabase/migrations/0193_sms_notifications.sql` (trigger `notifications_sms` → `sms_on_notification()` on `public.notifications` AFTER INSERT); setup `scripts/setup-sms.mjs`; recipe skill `~/.claude/skills/sms-gateway/SKILL.md`. Latest migration at time of writing: 0227. Prod project ref `mdlnfhyylvapzdubhyic`; runtime authority `src/lib/supabase.ts`; the `mcp__supabase__*` tools point at jta-sys and must not be used against KTC.*
