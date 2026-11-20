# Evidence — subscription-checkout-design-pass

Four PNGs cover `/app/subscriptions/checkout` at 390 and 1440 wide, before
and after the design pass, captured by `agent-browser` driving Chrome
against a `MIX_ENV=dev mix phx.server` instance of this worktree on
`http://127.0.0.1:4091`.

The browser was signed in as the seeded direct marketer
`direct@example.com` (password `hello world!`) on the direct client
account **Direct Marketer LLC** from `priv/repo/seeds.exs`. Before each
shot the LiveView socket was confirmed connected
(`window.liveSocket.isConnected()`) and `location.pathname` was read
back as `/app/subscriptions/checkout`. The seed file ships no plans by
default, so one platform plan (`MetricFlow Pro`, $49.00/month,
`agency_account_id = NULL`) was inserted into `billing_plans` so the
page had a plan to render.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|----------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. A daisyUI `<.header>` with "Choose Your Plan" + muted subtitle, then a `card bg-base-100 shadow` plan panel with a centred title, price and bullet list, and a `btn btn-primary` "Subscribe" button. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop. No column cap, so the single card stretches across the main column. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. Content wrapped in `<main data-role="checkout-root" class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden">`. Uppercase eyebrow "Choose Your Plan", single `h1` "Unlock the AI features with a subscription", one-sentence lede. One Anderson BI plan card (`rounded-box border border-neutral bg-base-200`) with left-aligned plan name, price in the page's text colour, three feature lines, and a full-width `btn-brand-gradient` Subscribe button carrying the plan's price in its label. `document.documentElement.scrollWidth` equals `innerWidth` (both 390). |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop. Same markup; the `max-w-3xl` cap centres the content as one readable column and the plan card sits at the left of the two-column grid, pushing the pay button to one obvious landing spot. |

## How they were produced

1. `MIX_ENV=dev DATABASE_NAME=metric_flow_screenshot_checkout mix ecto.create`, `mix ecto.migrate`, and `mix run priv/repo/seeds.exs` on this worktree, then a single platform `billing_plans` row (`MetricFlow Pro`, `price_cents=4900`, `currency=usd`, `billing_interval=monthly`, `agency_account_id=NULL`) inserted via `psql` so the checkout page has a plan to render.
2. `MIX_ENV=dev DATABASE_NAME=metric_flow_screenshot_checkout PORT=4091 mix phx.server` started a dev server on `http://127.0.0.1:4091`.
3. `agent-browser` signed in at `/users/log-in` as `direct@example.com / hello world!`, which lands on the Direct Marketer LLC account by default, then navigated to `/app/subscriptions/checkout` and verified the page was LiveView-connected and on the right path.
4. For each state (before / after) and viewport (390x844 / 1440x900), the right version of `lib/metric_flow_web/live/subscription_live/checkout.ex` was in place (committed `HEAD` for before, this commit's edited file for after), the browser was reloaded, and `agent-browser screenshot body <path> --full` wrote the PNG.

## What the pass's structural claims are verified by

`test/metric_flow_web/live/subscription_live/checkout_test.exs` under
the "Anderson BI layout" describe block fails against the pre-pass
template and passes after the edit:

- The page is wrapped in `<main data-role="checkout-root">` whose class carries both `overflow-x-hidden` and a `max-w-*` cap.
- Exactly one `<h1>` lives inside that root.
- Each plan renders as a `data-role="plan-card"` article, and the subscribe button uses the `btn-brand-gradient` component class and keeps its `data-role="subscribe-button"`.
