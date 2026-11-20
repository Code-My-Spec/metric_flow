# Evidence — help-account-origination-design-pass

Four PNGs cover `/app/help/account-origination` at 390 and 1440 wide,
before and after the design pass, captured by `agent-browser` driving
Chrome against a `mix phx.server` instance of the metric_flow checkout
on `http://127.0.0.1:4070`.

The browser was signed in as the seeded agency owner
`joel@example.com` (password `hello world!`) and active account
**Anderson the Fish** from `priv/repo/seeds.exs`. Before each shot the
LiveView socket was confirmed connected
(`window.liveSocket && window.liveSocket.isConnected()`),
`location.pathname` was read back as `/app/help/account-origination`,
and the sidebar's `data-role="current-account-name"` was read back as
`Anderson the Fish`. At 390 wide,
`document.documentElement.scrollWidth === window.innerWidth` was read
back as `390 === 390` on the after shot — no sideways scroll on a
390px phone.

The page is static help content — the seed state does not vary its
render — so all four shots are of the same "four origination routes"
page, with the only variable being the layout and tokens.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|----------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page: the `<.header>` component prints a small `h1` "How Account Origination Works" with a muted subtitle, and the four sections run as plain `<section><h3>` headings inside a `prose prose-sm` wrapper that resolves to nothing (no `@tailwindcss/typography` plugin is loaded), so body copy renders as unstyled paragraphs with no card, no padding and no visual grouping. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop: content stretches from the sidebar to the right edge with no width cap narrower than the layout's `max-w-3xl`, and the plain `<h3>` and `<p>` sit directly on the page background. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page: content wrapped in `<main data-role="help-account-origination-root" class="mx-auto w-full max-w-2xl space-y-6 overflow-x-hidden">`. Uppercase "Help" eyebrow, single `h1` "How Account Origination Works", one-sentence lede. Each of the four origination routes lives in its own Anderson BI card (`rounded-box border border-neutral bg-base-200`) with an `h2` title and body text sized at `text-sm leading-relaxed`. The Clients page link (`data-role="help-origination-clients-link"`) is visible under the referral-links card. `scrollWidth === innerWidth` at 390. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop: same markup; the `max-w-2xl` cap centres the help content as one readable column instead of stretching it across the full main column. |

## How they were produced

1. The running `mix phx.server` at `http://127.0.0.1:4070` was serving
   the seeded dev database (`metric_flow_dev`) with the users and
   accounts from `priv/repo/seeds.exs`, including `joel@example.com`
   owning "Anderson the Fish".
2. `agent-browser` signed in at `/users/log-in` as
   `joel@example.com / hello world!` and landed on `/app/agency/clients`
   with Anderson the Fish active (the ActiveAccountHook picks the most
   recently updated membership; the seed order lands Anderson the Fish
   as active).
3. For each state (before / after) and viewport (390x844 / 1440x900)
   the right version of
   `lib/metric_flow_web/live/help_live/account_origination.ex` was in
   place, the browser was navigated to the page, the LiveView socket
   was confirmed connected, and `agent-browser screenshot` wrote the
   PNG.

## What the pass's structural claims are verified by

`test/metric_flow_web/live/help_live/account_origination_test.exs`
under the "Anderson BI layout" describe block fails against the
pre-pass template and passes after the edit:

- The page is wrapped in `<main data-role="help-account-origination-root">` whose class carries both `overflow-x-hidden` and a `max-w-*` cap.
- Exactly one `<h1>` lives inside that root.
- The root carries no `prose` classes, no hard-coded hex colours, and no raw tailwind palette shades — only Anderson BI tokens (`base-*`, `primary`, `neutral`, `text-base-content/*`).
- A visible link to `/app/agency/clients` still lives inside the root so the referral-links reader can still reach the Clients page in one tap.
