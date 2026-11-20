# Evidence — account-members-design-pass

Full-page PNGs of `/app/accounts/members` captured as the seeded agency
owner `joel@example.com` (dev password `hello world!`) on the active
agency account `Anderson the Fish`, against the shared `metric_flow_dev`
database that `priv/repo/seeds.exs` sets up.

At each viewport the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was `true`,
`location.pathname === "/app/accounts/members"` was confirmed,
`[data-role="current-account-name"]` read back `"Anderson the Fish"`,
and `document.documentElement.scrollWidth === <viewport>` was read back.
At 390, `scrollWidth === 390` — no sideways scroll on a 390px phone.
At 1440, `scrollWidth === 1440`.

The before shots were taken against the main worktree's running dev
server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`,
checked out at commit `eb8d2963` — the "issue as handed in" commit,
which leaves `lib/metric_flow_web/live/account_live/members.ex`
identical to its parent, so port 4070 renders the pre-pass markup). The
after shots were taken from this worktree's own `mix phx.server`
(MIX_ENV=dev, PORT=4099) on the exact code committed in this change.
Both servers share the same seeded `metric_flow_dev` database, so the
same logged-in `joel@example.com` session reached both URLs.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page. The page opens with a bare `<.header>Members</.header>` block, then the members `<div class="card bg-base-100 shadow">` list and the agency-grants `card`, with the Invite Member card tacked on last. The primary action (Invite) is the smallest thing on the page — a plain `btn btn-primary` buried at the bottom of the bottom card. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop: the same bare `<.header>`, the same three stacked `card bg-base-100 shadow` panels, and the same bottom-of-page Invite button. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.app`. The main column (`mx-auto max-w-3xl space-y-6 overflow-x-hidden`) leads with the plain `<h1>Members</h1>` + account-name subtitle, then puts the **Invite a Member** card (`rounded-box border border-neutral bg-base-200`) with the full-width `btn-brand-gradient` submit as the primary action. Below it, Current members and Agency access are their own `rounded-box border border-neutral bg-base-200` panels; the table inside each panel scrolls locally under `overflow-x-auto` so the main column does not. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop, same card markup pinned to a centred `max-w-3xl` column inside `Layouts.app`. Invite first; Current members second; Agency access third. The app shell draws the sidebar and top bar around it. |

## How it was checked

- `MIX_ENV=test mix test` — 3171 tests pass, 3 excluded, 0 failures.
- `MIX_ENV=test mix test test/metric_flow_web/live/account_live/members_test.exs` — 15 tests pass (14 original + 1 new Anderson BI token assertion).
- `MIX_ENV=test mix test test/journeys/account_administration_and_team_management_test.exs test/journeys/agency_white_label_and_multi_client_access_test.exs` — all pass.
- `mix spex --pattern "**/3_multi-user_account_access/*_spex.exs"` — 20 pass.
- `mix spex --pattern "**/7_manage_user_access_permissions/*_spex.exs"` — 15 pass.
- `mix spex --pattern "**/8_agency_views_and_manages_client_accounts/*_spex.exs"` — 22 pass.
- `mix spex --pattern "**/4_agency_team_auto-enrollment/*_spex.exs" --pattern "**/5_client_invites_agency_or_individual_user_access/*_spex.exs" --pattern "**/6_agency_or_user_accepts_client_invitation/*_spex.exs" --pattern "**/32_account_deletion_owner_only/*_spex.exs"` — 20 pass.
- `agent-browser` (headless Chromium) drove `/app/accounts/members` as `joel@example.com` on both servers. At each viewport the driver read back `location.pathname === "/app/accounts/members"`, `window.liveSocket && liveSocket.isConnected() === true`, `[data-role="current-account-name"] === "Anderson the Fish"`, and `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the pre-pass page carried is still rendered on the
same elements:

- `data-role="members-list"` on the members-list container (used by
  `test/metric_flow_web/live/account_live/members_test.exs`,
  `test/journeys/agency_white_label_and_multi_client_access_test.exs`
  and the `test/spex/8_agency_views_and_manages_client_accounts/`
  criteria 58/603/604/606/607).
- `data-role="member-row"` with `data-user-id` on each `<tr>` (kept as a
  `tr` because `criterion_531` and `criterion_536` spex use
  `tr[data-role='member-row']` and `tr[data-role='member-row'] span.badge`
  selectors).
- `data-role="change-role"` sr-only button with `data-user-email`,
  `phx-click="change_role"` and `phx-value-user_id` (used by the
  criterion_46 / criterion_20 / criterion_535 / criterion_536 /
  criterion_538 / criterion_26 / criterion_593 spex via `render_click`).
- `data-role="remove-member"` button with `data-user-email`,
  `phx-click="remove_member"` and `phx-value-user_id` (used by
  criterion_48 / criterion_50 / criterion_21 / criterion_537 /
  criterion_538 / criterion_559).
- `#invite_member_form` with `phx-submit="invite_member"` and
  `name="invitation[email]"` / `name="invitation[role]"` inputs (used by
  40+ spex across sections 3, 4, 5, 6, 7, 8, 30, 32 and 56, plus
  `test/support/shared_givens.ex`).
- `data-role="agency-access-list"` and `data-role="agency-grant-row"`
  with `data-agency-account-id` on each grant row.
- The row-level role change `<form phx-submit="change_role">` with its
  hidden `user_id` input and `role` select, still reachable as
  `[data-role='member-row'][data-user-id='X'] form` (used by
  `test/journeys/account_administration_and_team_management_test.exs`
  and the members unit tests).
- The role-label `<span>` inside each row still carries the `badge`
  class as its first token so `tr[data-role='member-row'] span.badge`
  (criterion_536) still matches.
- The `change_role`, `remove_member` and `invite_member` LiveView event
  names and param shapes are unchanged.

New attributes added by this pass are purely additive: the invite
section carries `id="invite-member-heading"` so its surrounding
`<section>` can `aria-labelledby` it, and the invite-form inputs have
`id="invite_member_email"` / `id="invite_member_role"` so their
`<label for="...">` elements point at them.
