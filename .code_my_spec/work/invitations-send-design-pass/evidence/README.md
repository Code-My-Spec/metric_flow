# Evidence — invitations-send-design-pass

Full-page PNGs of `/app/accounts/invitations` captured as the seeded
agency owner `joel@example.com` (dev password `hello world!`) on the
active agency account `Anderson the Fish`, against the shared
`metric_flow_dev` database that `priv/repo/seeds.exs` sets up.

At each viewport the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was `true`,
`location.pathname === "/app/accounts/invitations"` was confirmed,
`[data-role="current-account-name"]` read back `"Anderson the Fish"`,
and `document.documentElement.scrollWidth === <viewport>` was read back.
At 390, `scrollWidth === 390` — no sideways scroll on a 390px phone.
At 1440, `scrollWidth === 1440`.

The before shots were taken against the main checkout's running dev
server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`,
checked out at the "issue as handed in" commit `1abf8aab`, which leaves
`lib/metric_flow_web/live/invitation_live/send.ex` identical to its
parent, so port 4070 renders the pre-pass markup). The after shots were
taken from this worktree's own `mix phx.server` on port 4099 against
the same seeded `metric_flow_dev` database, on the exact code committed
in this change.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page. Uses the undefined `mf-content` wrapper and the undefined `mf-card` panels (no CSS rule matches them in `assets/css/app.css`), so the "cards" are plain full-width blocks with no border or surface tint. The primary action is a small daisyUI `btn btn-primary` buried below two form fields. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop: same `mf-content` + two `mf-card p-6` panels stacked full width in the main column, no Anderson BI tokens, same small primary button. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.app`. The main column (`mx-auto max-w-3xl space-y-6 overflow-x-hidden`) leads with the plain `<h1>Invite Members</h1>` + account-name subtitle and a small "Back to Members" link. Below it, the **Send an Invitation** section (`rounded-box border border-neutral bg-base-200`) carries the form with `<label>`-above-input layout and a full-width `btn-brand-gradient rounded-box` submit as the primary action. Below that, **Pending Invitations** is its own `rounded-box border border-neutral bg-base-200` panel with a `divide-y divide-neutral` list of invitees and Anderson BI role badges. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop: same card markup pinned to a centred `max-w-3xl` column inside `Layouts.app`. Invite first, Pending Invitations second. The app shell draws the sidebar and top bar around it. |

## How it was checked

- `mix test` — 3173 tests pass, 3 excluded, 0 failures.
- `mix test test/metric_flow_web/live/invitation_live/send_test.exs` — 9 tests pass (8 original + 1 new Anderson BI token assertion that fails on the pre-pass file).
- `mix test test/metric_flow_web/live/account_live/members_test.exs test/journeys/account_administration_and_team_management_test.exs` — all pass.
- `mix spex --pattern "**/5_client_invites_agency_or_individual_user_access/*_spex.exs"` — 16 pass.
- `agent-browser` (headless Chromium) drove `/app/accounts/invitations` as `joel@example.com` on both servers. At each viewport the driver read back `location.pathname === "/app/accounts/invitations"`, `window.liveSocket && liveSocket.isConnected() === true`, `[data-role="current-account-name"] === "Anderson the Fish"`, and `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the pre-pass page carried is still rendered on the
same elements:

- `data-role="invite-form-section"` on the send-invitation `<section>`
  (used by `test/metric_flow_web/live/invitation_live/send_test.exs`).
- `data-role="pending-invitations"` on the pending-invitations
  `<section>` (used by the same test file).
- `data-role="submit-invite"` on the primary submit button.
- `#invite_member_form` with `phx-submit="send_invitation"` and
  `phx-change="validate"`, with `name="invitation[email]"` and
  `name="invitation[role]"` inputs (used across the send tests).
- `data-role="pending-invitation-row"` with `data-invitation-id` on
  each list item.
- `data-role="invitation-email"` on the email cell of each row.
- `data-role="cancel-invitation"` with `data-email`,
  `phx-click="cancel_invitation"` and `phx-value-id` on the Cancel
  button.
- The `validate`, `send_invitation` and `cancel_invitation` LiveView
  event names and param shapes are unchanged.

New attributes added by this pass are purely additive: the two sections
carry `id="send-invitation-heading"` / `id="pending-invitations-heading"`
so they can `aria-labelledby` their own `<h2>`, and the invite form
inputs have `id="invitation_email"` / `id="invitation_role"` so their
`<label for="...">` elements point at them.
