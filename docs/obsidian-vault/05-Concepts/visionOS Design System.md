---
title: visionOS Design System
tags: [concept, frontend, design]
type: concept
---

# 🎨 visionOS Design System

KTC reuses the jta-sys v2 "visionOS" design language, re-skinned to the KTC brand.

## Tokens & aesthetic

- Cool-neutral canvas, frosted-glass surfaces (`rgba(255,255,255,.6)` blur + saturate), soft motion.
- KTC brand accent: **orange `#F26A21`** / **red `#D6321E`** (from the KTC logo) — used ONLY for actions and signals, never decoration ("Harbor Glass" discipline, 2026-06-11).
- Logo: `assets/ktc-logo.png` (white background keyed out → transparent). Served at `/ktc-logo.png`.
- Fonts (2026-06-11): **Schibsted Grotesk** (UI/display, `--font-sans`) + **IBM Plex Mono** (`--font-mono`, for JO numbers / container numbers / customer codes). Loaded via Google Fonts in `index.html`, limited weights for speed.
- **Navigation:** persistent frosted top nav (`ktc-nav` / `ktc-nav-link`, active pill state) in both Shell and AdminShell — replaced the back-button + breadcrumb pattern (2026-06-11).
- **Motion:** one orchestrated page-load stagger (`ktc-stagger` on the Shell content / `ktc-rise` for single panels), spring card hovers, modal pop-in. All gated by `prefers-reduced-motion`.
- **Code splitting:** admin pages + the print view are `React.lazy` chunks — customers never download the admin bundle.

## Reusable classes

- `ktc-glass` — frosted card surface (regular material)
- `ktc-glass-thin` / `ktc-glass-thick` — lighter / heavier material tiers (2026-06-11)
- `ktc-card` — additive interactive physics for glass links/buttons: spring hover lift + press settle (respects `prefers-reduced-motion`)
- `ktc-btn` — primary gradient button · `ktc-btn--sm` compact size
- `ktc-btn-secondary` — frosted secondary button
- `ktc-chip` + `ktc-chip--{success,info,progress,warning,danger,accent}` — semantic status pills (dot + label); job-order statuses map to these in `MyJobOrders.tsx`
- `ktc-skeleton` — shimmer loading placeholder
- `ktc-nav` / `ktc-nav-links` / `ktc-nav-link` (+ `.is-active`) — frosted top navigation (2026-06-11)
- `ktc-title` / `ktc-sub` / `ktc-mono` — typography helpers (page title, subtitle, technical mono)
- `ktc-rise` / `ktc-stagger` — page-load reveal (single element / staggered children)
- `ktc-modal-backdrop` / `ktc-modal-panel` — modal system (blurred dim + spring pop-in); used by `FileViewerModal`
- `ktc-input` — form input
- `ktc-label` — muted label text
- `ktc-link` — text button / link

Tokens live in `src/styles/v2-tokens.css` — including material tiers (`--glass-thin/-thick`), spring easing (`--ease-spring`) + duration tokens, and semantic status tones (`--tone-*-bg/-ink`). Reuse these classes rather than re-rolling inline styles where possible.

## Ambient & a11y layer (2026-06-11)

- **Aurora canvas:** two slow-drifting brand-tinted blurred orbs (`body::before/::after`, fixed, `z-index:-1`, pointer-events none). Disabled under `prefers-reduced-motion` and `@media print`.
- **Focus ring:** global `:focus-visible` accent ring for keyboard navigation.

## Origin

The system was ported from how jta-sys styles its v2 surfaces, so the two apps feel related while KTC keeps its own accent and logo.

## Related

- [[Tech Stack]] · [[Architecture]]
- ADR-0003
