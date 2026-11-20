# Evidence -- accounts-index-design-pass

Full-page PNGs of `/app/accounts` captured as the seeded agency owner
`joel@example.com` (dev password `hello world!`), who in
`priv/repo/seeds.exs` is a member of both the agency account `Anderson
the Fish` and the client account `Anderson Retail Co.`, so multiple
cards render on both viewports.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was `true`,
`location.pathname === "/app/accounts"` was confirmed, and
`document.documentElement.scrollWidth === <viewport>` was read back: at
390 `scrollWidth === 390` (no sideways scroll at a 390px phone), at
1440 `scrollWidth === 1440`.

The before shots were taken against the main worktree's running dev
server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`,
currently checked out at commit `737ac5c8` -- the "issue as handed in"
commit, which only adds `issues/accounts-index-design-pass.yml` and
leaves `lib/metric_flow_web/live/account_live/index.ex` identical to its
parent, so port 4070 renders the pre-pass markup). The after shots were
taken from this worktree's own `mix phx.server` (MIX_ENV=dev, PORT=4099)
on the exact code committed in this change. Both servers share the
seeded `metric_flow_dev` database set up by `mix run priv/repo/seeds.exs`,
so the same signed-in `joel@example.com` session reached both URLs.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x895   | before | Pre-pass phone page inside `Layouts.app`. Content column is a bare `mx-auto` wrapper around a `<.header>Your Accounts</.header>` followed by one `card bg-base-200 p-6` per account, each row showing the account name full width, four daisyUI `badge`s wrapping below (`badge-primary`/`badge-secondary`/`badge-ghost`/`badge-accent`/`badge-info`), and a small `btn btn-sm btn-primary` "Switch to ..." pill tucked into the top-right of the row. `Create Team Account` is a stack of `form-control` + `label` + `.input` + bottom-aligned `btn btn-primary`. |
| `before-1440.png` | 1440x1017 | before | Same pre-pass markup on desktop inside `Layouts.app`. Two bare `card bg-base-200` rectangles stretch the full width of the main column with the small `btn-primary` switch button pinned to the top-right of each. |
| `after-390.png`   | 390x912   | after  | Post-pass phone page in `Layouts.app`. Each account is a `rounded-box border border-neutral bg-base-200 p-4 sm:p-6` card (active swaps to `border-primary`) showing the account name, a `rounded-box border` Type pill and a `Role: owner`/`Role: member` pair, and a full-width `btn-brand-gradient rounded-box` switch button along the bottom (`<Name> Active` when the card is the active one, `Switch to <Name>` otherwise). `Create Team Account` is its own `rounded-box border border-neutral bg-base-200` form card with `<.input label="...">` inputs and a `btn-brand-gradient` submit. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x1017 | after  | Post-pass desktop page, same card markup pinned to a centred `max-w-3xl` column inside `Layouts.app`. The sidebar and top bar render around it per `DESIGN.md -- Shell`. |

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/account_live/index_test.exs`
  -- 12 tests passed, including the new
  `account cards use rounded-box + border + bg-base-200 tokens and
  switch is the brand-gradient primary` test in the
  `renders each account as an Anderson BI card` describe block. That
  test fails on the pre-pass file (confirmed by inspection: the pre-pass
  markup emits `class="card bg-base-200 p-6"` on each account card and
  `class="btn btn-sm btn-primary"` on each switch button, neither of
  which contains `rounded-box` or `btn-brand-gradient`).
- `MIX_ENV=test mix test` -- 3170 passed, 3 excluded.
- `MIX_ENV=test mix test test/journeys/agency_white_label_and_multi_client_access_test.exs test/metric_flow_web/live/account_live/`
  -- 46 passed. The journey test still finds
  `[data-role='account-card'][data-account-id][data-active='true']`
  after each switch, so the structural data-* attributes the switcher
  depends on are intact.
- Spex covering the account switcher continue to pass:
  `criterion_53_agency_can_switch_between_client_accounts_via_account_switcher`,
  `criterion_598_agency_switches_between_client_accounts`,
  `criterion_599_navigation_clearly_displays_the_current_client_context`,
  `criterion_1072_a_read-only_member_cannot_start_a_dashboard`,
  `criterion_513_user_registers_with_a_valid_email_and_password`,
  `criterion_539_users_on_the_same_account_share_the_same_data`,
  `criterion_907_user_revokes_their_own_access_from_account_settings`,
  `criterion_908`, `criterion_909`, `criterion_910`, `criterion_911`,
  `criterion_60`, `criterion_61`, `criterion_62`, `criterion_63`,
  `criterion_64`, and
  `criterion_1029_jordans_youtube_connection_stays_with_jordans_account`.
  The spex that look for `"Client 599 Active"` or
  `"Switch to Owner Account"` text on `[data-role='switch-account']`
  still match because the active-account button now reads
  `"<Name> Active"` (no parentheses) and the inactive button still
  reads `"Switch to <Name>"`.
- `agent-browser` (headless Chromium) drove `/app/accounts` as
  `joel@example.com` on both servers. At each viewport the driver read
  back `location.pathname === "/app/accounts"`,
  `window.liveSocket && liveSocket.isConnected() === true`, and
  `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered on the same
elements:

- `data-role="account-card"` on each row, with the same
  `data-account-id="<id>"` and `data-active="true|false"` attributes.
- `data-role="switch-account"` on each switch button, with the same
  `phx-click="switch_account"` and `phx-value-account_id="<id>"`.
- The `switch_account`, `create_team`, and `validate_team` LiveView
  event names are unchanged, as is the shape of the `"team"` form
  params POSTed to `create_team`.

New attributes added by this pass are purely additive: the accounts
list section has `id="accounts"`, the create-team form has
`id="team_form"`, and the create-team heading has
`id="create-team-heading"` so the surrounding `<section>` can
`aria-labelledby` it.
