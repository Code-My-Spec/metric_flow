# Evidence — account-transfer-accept-design-pass

Full-body PNGs of `/account_transfers/<token>` captured as the seeded
agency owner `joel@example.com` (dev password `hello world!`) on a
freshly created pending ownership transfer of the seeded client account
`Anderson Retail Co.` (initiator `client@example.com`, target
`joel@example.com`, `remain_admin: false`), against the shared
`metric_flow_dev` database that `priv/repo/seeds.exs` sets up.

At each viewport the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was `true`,
`location.pathname === "/account_transfers/<token>"` was confirmed, and
`document.documentElement.scrollWidth === <viewport>` was read back.
At 390, `scrollWidth === 390` — no sideways scroll on a 390px phone.
At 1440, `scrollWidth === 1440`.

The before shots were taken against the main checkout's running dev
server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`),
which renders the pre-pass `lib/metric_flow_web/live/account_transfer_live/accept.ex`
(unchanged since commit `8d5ef54e`, the "Story 10: build Transfer Account
Ownership" commit). The after shots were taken from this worktree's own
`mix phx.server` on port 4099 against the same seeded `metric_flow_dev`
database, on the exact code committed in this change. The accept
button's `className` was verified before screenshotting: port 4070 read
back `"btn btn-primary w-full"`, port 4099 read back
`"btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"`.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|---------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. Uses the undefined `mf-content` wrapper and the undefined `mf-card` panel (no CSS rule matches them in `assets/css/app.css`), so the "card" is a plain full-width block with no border or surface tint. Centred `h2` "Confirm Ownership Transfer", one sentence naming the initiator and the account, a daisyUI `<div class="divider">`, and a single full-width `btn btn-primary` labelled "Accept Ownership". No explanation of what changes on accepting. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop, vertically centred in a tall `min-h-[80vh]` flex box inside the public layout. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page in `Layouts.content`. One Anderson BI card (`rounded-box border border-neutral bg-base-200`) leads with the `<h1>` "Become the owner of Anderson Retail Co." and an eyebrow label ("Ownership transfer"), followed by one line naming the initiator's email. A three-item bullet list spells out what changes on accepting (sole owner, previous owner demoted to Account Manager, connected data stays). One clear primary action — the full-width `btn-brand-gradient rounded-box` **Accept ownership of Anderson Retail Co.** button — with a small caption confirming the signed-in identity. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop. Same card pinned to a centred `max-w-md` column inside `Layouts.content`. |

## How it was checked

- `mix test test/metric_flow_web/live/account_transfer_live/accept_test.exs` — 4 tests pass (brand-gradient class, page explains what changes, accepting still redirects to settings with a success flash, logged-out visitor sees the log-in and register buttons).
- `mix test` — full suite green (3178 passed, 3 excluded).
- `mix spex --pattern "**/10_transfer_account_ownership/*_spex.exs"` — 23 pass.
- `mix spex --pattern "**/32_account_deletion_owner_only/*_spex.exs"` — 20 pass.
- `mix spex --pattern "**/9_user_or_agency_self-revokes_access/*_spex.exs"` — 12 pass.
- `mix spex --pattern "**/7_manage_user_access_permissions/*_spex.exs"` — 15 pass.
- `agent-browser` (headless Chromium) drove `/account_transfers/<token>` on both servers. At each viewport the driver read back `location.pathname`, `window.liveSocket && liveSocket.isConnected() === true`, and `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the pre-pass page carried is still rendered on the
same elements:

- `data-role="accept-transfer-btn"` on the primary gradient Accept button
  (used across `test/spex/10_transfer_account_ownership/` and
  `test/spex/32_account_deletion_owner_only/`, plus
  `test/metric_flow_web/live/account_transfer_live/accept_test.exs`).
- `data-role="log-in-to-confirm-btn"` and
  `data-role="register-to-confirm-btn"` on the logged-out call-to-action
  buttons (used by
  `test/spex/10_transfer_account_ownership/criterion_70_*_spex.exs` and
  `criterion_900_*_spex.exs`).
- The `accept`, `log_in_to_confirm` and `register_to_confirm` LiveView
  `phx-click` event names are unchanged.

The one additive id is `id="transfer-heading"` on the `<h1>`, which the
card's `aria-labelledby` points at.
