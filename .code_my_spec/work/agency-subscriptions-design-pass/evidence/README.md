# Evidence — agency-subscriptions-design-pass

Four PNGs cover `/app/agency/subscriptions` at 390 and 1440 wide, before
and after the design pass, captured by `agent-browser` driving Chrome
against a `MIX_ENV=dev mix phx.server` instance of this worktree.

The browser was signed in as the seeded agency owner
`joel@example.com` (password `hello world!`) on the agency account
**Anderson the Fish** from `priv/repo/seeds.exs`, and the LiveView
socket was confirmed connected (`window.liveSocket.isConnected()`)
with `location.pathname === "/app/agency/subscriptions"` before each
shot.

The seed data does not create any customer subscriptions for Anderson
the Fish, so each screenshot shows the empty-list state of the page.
The pass's structural change — the Anderson BI shell around the list —
is what differs between before and after.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|----------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. daisyUI `<.header>` "Customer Subscriptions" with a muted subtitle, a `stats shadow w-full` row (Active Subscribers / MRR / Past Due), a full-width search input, and a `card bg-base-100 shadow` panel whose body reads "No customer subscriptions yet". |
| `before-1440.png` | 1440x1017| before | Same pre-pass markup on desktop. The `<.header>`, the `stats shadow` row and the empty-state card all stretch across the full main column. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. Content wrapped in `<main data-role="agency-subscriptions-root" class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden">`. Uppercase eyebrow "Customer Subscriptions", single `h1` "Watch your clients' subscriptions", one-sentence lede saying problems lead the list. Three Anderson BI stat cards (Active Subscribers, MRR, Past Due) stacked in a single column. Search sits in its own `rounded-box border border-neutral bg-base-200` panel with a "Search customers" label above the input. Empty-list panel is the new `rounded-box border border-neutral bg-base-200 p-6 text-center` with the one-line body text. `document.documentElement.scrollWidth` equals `innerWidth` (both 390). |
| `after-1440.png`  | 1440x1017| after  | Post-pass desktop. Same markup as `after-390` but the stat cards reflow onto a three-column grid at `sm:` and the `max-w-3xl` main column is centred inside the app shell so the content reads as one readable column rather than stretching across the full viewport. |

## How they were produced

1. `MIX_ENV=dev mix ecto.create` and `mix ecto.migrate` on
   `metric_flow_dev`, then `MIX_ENV=dev mix run priv/repo/seeds.exs` to
   seed Joel Anderson and the "Anderson the Fish" agency.
2. `MIX_ENV=dev PORT=4091 mix phx.server` started a dev server on
   `http://127.0.0.1:4091`, then confirmed up with
   `curl http://127.0.0.1:4091/health`.
3. `agent-browser` drove Chrome at `http://127.0.0.1:4091/users/log-in`,
   signed in as `joel@example.com / hello world!`, navigated to
   `/app/agency/subscriptions`, and verified the page was
   LiveView-connected and on the right pathname.
4. For each state (before / after) and viewport (390x844 / 1440x900),
   the right version of `lib/metric_flow_web/live/agency_live/subscriptions.ex`
   was in place (committed `HEAD` for after, `git checkout d6f8d1c4 --`
   for before), the browser was reloaded, and
   `agent-browser screenshot --full` wrote the PNG. The working-tree
   file was restored to `HEAD` before committing the evidence.

## What the pass's structural claims are verified by

`test/metric_flow_web/live/agency_live/subscriptions_test.exs` under
the "Anderson BI layout" describe block fails against the pre-pass
template and passes after the edit:

- The page is wrapped in `<main data-role="agency-subscriptions-root">`
  whose class includes both `overflow-x-hidden` and a `max-w-*` cap.
- Exactly one `<h1>` lives inside the root.
- Each client subscription renders as its own `data-role="subscription-row"`
  article carrying `data-status="<subscription status>"`.
- Problem-status subscriptions (`past_due`, `incomplete`) appear in the
  rendered HTML before healthy (`active`, `trialing`) ones, even when
  they were inserted earlier (the pre-pass `inserted_at desc` order
  would place the healthy row first).
