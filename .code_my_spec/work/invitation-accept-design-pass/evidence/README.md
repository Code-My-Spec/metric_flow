# Evidence — invitation-accept-design-pass

Full-body PNGs of `/invitations/<token>` captured as the seeded agency
owner `joel@example.com` (dev password `hello world!`) on a freshly
created pending invitation to the seeded client account
`Anderson Retail Co.` (role `Read Only`, invitee
`invitee-screenshot@example.com`), against the shared `metric_flow_dev`
database that `priv/repo/seeds.exs` sets up.

At each viewport the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was `true`,
`location.pathname === "/invitations/<token>"` was confirmed, and
`document.documentElement.scrollWidth === <viewport>` was read back.
At 390, `scrollWidth === 390` — no sideways scroll on a 390px phone.
At 1440, `scrollWidth === 1440`.

The before shots were taken against the main checkout's running dev
server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`,
checked out at commit `3edca14e`, the "issue as handed in" commit, which
leaves `lib/metric_flow_web/live/invitation_live/accept.ex` identical to
the pre-pass starting point of this worktree). The after shots were
taken from this worktree's own `mix phx.server` on port 4099 against
the same seeded `metric_flow_dev` database, on the exact code committed
in this change. The accept button's `className` was verified before
screenshotting: port 4070 read back `"btn btn-primary w-full"`, port
4099 read back `"btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"`.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x915   | before | Pre-pass phone page. Uses the undefined `mf-content` wrapper and the undefined `mf-card` panel (no CSS rule matches them in `assets/css/app.css`), so the "card" is a plain full-width block with no border or surface tint. A circular avatar sits above the heading, then a `btn btn-primary` Accept button and a `btn btn-ghost` Decline button. |
| `before-1440.png` | 1440x960  | before | Same pre-pass markup on desktop. Content is vertically centred in a tall `min-h-[80vh]` flex box inside the public layout. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.content`. One Anderson BI card (`rounded-box border border-neutral bg-base-200`) leads with the plain `<h1>Join Anderson Retail Co.</h1>` and an eyebrow label ("You've been invited"), followed by one line naming the inviter's email and role. One clear primary action — the full-width `btn-brand-gradient rounded-box` **Accept Invitation** button — with a small text-only Decline below it. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop. Same card pinned to a centred `max-w-md` column inside `Layouts.content`. |

## How it was checked

- `mix test test/metric_flow_web/live/invitation_live/accept_test.exs` — 9 tests pass (8 original + 1 new Anderson BI token assertion that fails on the pre-pass file: the accept button must carry `btn-brand-gradient`).
- `mix test` — full suite green.
- `mix spex --pattern "**/6_agency_or_user_accepts_client_invitation/*_spex.exs"` — all pass.
- `mix spex --pattern "**/5_client_invites_agency_or_individual_user_access/*_spex.exs"` — all pass.
- `agent-browser` (headless Chromium) drove `/invitations/<token>` on both servers. At each viewport the driver read back `location.pathname`, `window.liveSocket && liveSocket.isConnected() === true`, and `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the pre-pass page carried is still rendered on the
same elements:

- `data-role="accept-btn"` on the primary gradient Accept button
  (used across `test/spex/5_client_invites_agency_or_individual_user_access/`,
  `test/spex/6_agency_or_user_accepts_client_invitation/`,
  `test/spex/56_connect_youtube_via_oauth/`,
  `test/support/shared_givens.ex`, and
  `test/metric_flow_web/live/invitation_live/accept_test.exs`).
- `data-role="decline-btn"` on the subtle Decline button
  (used by `accept_test.exs`).
- `data-role="log-in-btn"` and `data-role="register-btn"` on the
  logged-out call-to-action buttons (used by `criterion_38_*_spex.exs`,
  `criterion_832_*_spex.exs`, and `accept_test.exs`).
- The `accept`, `decline`, `log_in_to_accept` and `register_to_accept`
  LiveView `phx-click` event names are unchanged.

The one additive id is `id="invitation-heading"` on the `<h1>`, which
the card's `aria-labelledby` points at.
