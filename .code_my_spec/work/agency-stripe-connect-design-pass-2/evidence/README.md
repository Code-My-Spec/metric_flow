# Evidence — agency-stripe-connect-design-pass-2

Four PNGs cover `/app/agency/stripe-connect` at 390 and 1440 wide, before
and after the design pass, captured by `agent-browser` driving Chrome
against a `MIX_ENV=dev mix phx.server` instance of this worktree on
`http://127.0.0.1:4099`.

The browser was signed in as the seeded agency owner
`joel@example.com` (password `hello world!`) and switched to the agency
account **Anderson the Fish** from `priv/repo/seeds.exs`. Before each
shot the LiveView socket was confirmed connected
(`window.liveSocket.isConnected()`), `location.pathname` was read back
as `/app/agency/stripe-connect`, the sidebar's `data-role="current-account-name"`
was read back as `"Anderson the Fish"`, and at 390,
`document.documentElement.scrollWidth` was read back as `390` — no
sideways scroll on a 390px phone. At 1440 `scrollWidth === 1440`.

The seed file ships no Stripe connection for Anderson the Fish, so
every shot is of the `:not_connected` state the seeded agency owner
lands on. The one next action the page offers for that state is
**Connect Stripe Account**.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|----------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page: `<.header>` "Stripe Connect" with a muted subtitle, then a `card bg-base-100 shadow` whose body mixes the "Connection Status" title, a "Not connected" ghost badge, a muted-grey sales line and a small `btn btn-primary` "Connect Stripe Account" button. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop: the card stretches across the main column with no width cap. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page: content wrapped in `<main data-role="agency-stripe-connect-root" class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden">`. Uppercase eyebrow "Payments", single `h1` "Stripe Connect", one-sentence lede that names what connecting changes. One Anderson BI card (`rounded-box border border-neutral bg-base-200`) carrying the "Connection Status" heading, a "Not connected" badge, a short status detail line, and a full-width `btn-brand-gradient` "Connect Stripe Account" button — the one next action for this state. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop: same markup; the `max-w-3xl` cap centres the content as one readable column so the next action lands in one obvious spot instead of spanning the column. |

## How they were produced

1. `MIX_ENV=dev DATABASE_NAME=metric_flow_screenshot_stripe mix ecto.create`, `mix ecto.migrate`, and `mix run priv/repo/seeds.exs` on this worktree to lay down the seeded users and accounts (including `joel@example.com` owning "Anderson the Fish").
2. `MIX_ENV=dev DATABASE_NAME=metric_flow_screenshot_stripe PORT=4099 mix phx.server` started a dev server on `http://127.0.0.1:4099`.
3. `agent-browser` signed in at `/users/log-in` as `joel@example.com / hello world!`, then explicitly switched the active account to **Anderson the Fish** via `/app/accounts` (the ActiveAccountHook picks "most recently updated membership", which was Anderson Retail Co. after the seeds, so a Switch click was required to land on Anderson the Fish).
4. For each state (before / after) and viewport (390x844 / 1440x900), the right version of `lib/metric_flow_web/live/agency_live/stripe_connect.ex` was in place (committed `HEAD` for before, this commit's edited file for after), the browser was reloaded, and `agent-browser screenshot body <path> --full` wrote the PNG after the LiveView socket reported connected and `scrollWidth === innerWidth` was read back.

## What the pass's structural claims are verified by

`test/metric_flow_web/live/agency_live/stripe_connect_test.exs` under
the "Anderson BI layout" describe block fails against the pre-pass
template and passes after the edit:

- The page is wrapped in `<main data-role="agency-stripe-connect-root">` whose class carries both `overflow-x-hidden` and a `max-w-*` cap.
- Exactly one `<h1>` lives inside that root.
- The `:not_connected` state exposes exactly one `data-role="stripe-next-action"` and that action uses the `btn-brand-gradient` component class.
- The `:complete` state exposes exactly one `data-role="stripe-next-action"` (the Disconnect block), so each state offers one next action.
