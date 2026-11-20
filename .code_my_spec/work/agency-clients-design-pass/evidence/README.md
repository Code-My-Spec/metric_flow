# Evidence — agency-clients-design-pass

Before and after screenshots of /app/agency/clients at 390px and 1440px,
from the seeded dev database (priv/repo/seeds.exs plus a fresh owner-only
agency created inline). The DESIGN.md checklist asks for four shots per
pass; this folder has eight so both the populated and empty states are
visible at both widths.

## Shots

Populated agency — joel@example.com, agency "Anderson the Fish",
seeded with one client, "Anderson Retail Co.":

- `before-1440-populated.png` — pre-fix /app/agency/clients at 1440px
- `before-390-populated.png`  — pre-fix at 390px
- `after-1440-populated.png`  — post-fix at 1440px
- `after-390-populated.png`   — post-fix at 390px

Fresh-agency empty state — fresh-owner@example.com, agency
"Fresh Fish Agency", no client grants:

- `before-1440-empty.png` — pre-fix empty state at 1440px
- `before-390-empty.png`  — pre-fix empty state at 390px
- `after-1440-empty.png`  — post-fix empty state at 1440px
- `after-390-empty.png`   — post-fix empty state at 390px

## How they were captured

- `before-*` screenshots: the shared dev server at http://127.0.0.1:4070
  running the main-checkout code (b24a79d2, the pre-fix hand-in state) on
  the shared `metric_flow_dev` database after `mix run priv/repo/seeds.exs`
  and an additional `fresh-owner@example.com` / `Fresh Fish Agency` created
  via a small seed script.
- `after-*` screenshots: this worktree's own `mix phx.server` started on
  port 4071 against the same database, serving the committed post-fix
  code.
- Each shot was taken only after `window.liveSocket && liveSocket.isConnected()`
  returned true and `location.pathname === "/app/agency/clients"`; at 390
  width `document.documentElement.scrollWidth === 390`, i.e. nothing
  scrolls sideways.
- Joel's active account is "Anderson the Fish" in both before and after
  populated shots (confirmed via `[data-role='current-account-name']`).
