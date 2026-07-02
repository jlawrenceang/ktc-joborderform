# design-sync notes — ktc-portal

## State (2026-07-02): sync STOPPED by owner before build — design not refined yet

The owner's rule: the sync only replicates the current look as building blocks, and the current
design isn't final — so **do not sync until the design is refined in the app first**. Resume only
on an explicit owner ask.

What already happened (reusable, nothing uploaded):
- Project **created + pinned**: `KTC Portal Design System` (`projectId` in config.json). It is EMPTY.
  Because the pin predates the next run, that run takes the **atomic upload path** (fine — bulk upload).
- Owner decisions already made (don't re-ask): extended component scope (~22), author ALL previews,
  project name as above.

## Scope facts (from the 2026-07-02 coupling scan — re-verify components that changed since)

- Shape: `package`, **no library build** — app repo (Vite, `private: true`, no exports). Plan was a
  hand-authored synthetic entry file exporting the scoped set, passed via `--entry`.
- `useT` (src/lib/i18n.tsx) has a DEFAULT context (`t = identity`, lang 'en') — components using only
  `useT` render standalone in English, no provider needed.
- CLEAN: Modal, Notice, StickyActions, icons (46 named exports), OrgInfo, NotificationRow,
  VesselCalendar (named: MonthCalendar, Badge, fmt, fmtDT — no default export).
- CLEAN via useT-fallback: Wizard, SearchPicker, PasswordInput, PasswordStrength, OriginPill,
  ReleaseTracks, ContainerLinesEditor, XrayQueueTable, ServerBusyBanner, Clock, IdleWarning,
  LangToggle, RouteLoader, MfaGateError, ThemeToggle (side-effectful: localStorage + html[data-theme]).
- EXCLUDED (truly coupled): all app screens; ErrorBoundary (lib/errorReporting→supabase), PublicBrand
  (→NeedHelp→supabase), ProtectedDoc/SessionConflictModal (useAuth), PushToggle (lib/push), Turnstile
  (external Cloudflare script), InstallButton (renders only on beforeinstallprompt), HeroSlideshow +
  LaraAvatar (public image assets), WelcomeTour (data module, not a component).
- Styling: tokens in `src/styles/v2-tokens.css` + `src/styles/theme-colors.css`; ALL `.ktc-*` classes
  in `src/index.css` (single file, ~337 selectors); load order tokens→theme→index (src/main.tsx).
  Theme = `html[data-theme]`. Fonts: Google Fonts link in index.html — Schibsted Grotesk + IBM Plex
  Mono (no self-hosted @font-face) → plan was a small CSS with the Google Fonts @import (expect
  [FONT_REMOTE]). No tsconfig path aliases.

## Re-sync risks

- The coupling scan is point-in-time; components gain imports — re-run the scan (or at least re-check
  the scoped set's imports) before building.
- config.json holds both `projectId` and `pkg`, so the base skill will classify the next run as a
  re-sync and skip first-time expectations — the owner already knows the cost; scope decisions above.
