# Evidence — registration-design-pass

Full-page PNGs of `/users/register` captured logged-out from this worktree's
own `mix phx.server` (MIX_ENV=dev, port 4098) running against the seeded
`metric_flow_pddp` database (`priv/repo/seeds.exs`). The page is public:
no fixture login is required to reproduce.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned `true` and
`location.pathname === "/users/register"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` was read back before the
shot — the page has no sideways scroll at a 390px viewport. At 1440,
`document.documentElement.scrollWidth === 1440`.

The before shots were taken on the issue-as-handed-in file (commit
`74d58713`) before any edits. The file was then rewritten; Phoenix
live-reload re-rendered the new markup, and the after shots were captured
on the exact code committed in this change.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page inside `Layouts.content` (so the public header and footer are there) but the registration body itself is bare: a `mx-auto max-w-sma` wrapper (typo for `max-w-sm`) with no card, no logo above the heading, a `btn btn-outline` Google link, a plain daisyUI `.divider` of "or", a native `<select>` for Account type on the page background, and a `btn btn-primary` submit button. Nothing marks this as Anderson BI; the account-type choice is a select with a two-paragraph help block underneath. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. The form stretches toward the full content column because `max-w-sma` is not a Tailwind class, so the browser ignores it and the form sits at full width of the `Layouts.content` 1400px column. No logo, no card, no gradient. |
| `after-390.png`   | 390x1146  | after  | Post-pass phone page in `Layouts.content`. The inline `/images/anderson-bi-logo.png` (`data-role="default-logo"`) sits above a centred `max-w-md` card drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`), matching the login card. The card contains, in order: a Google button (`#google-register`, `data-login-method="google"`), an "or sign up with your email" divider, the `#registration_form` form with Email, Password, Account name, Account type, and the brand-gradient `Create an account` submit. The account-type `<select>` keeps `aria-describedby="account-type-help"` and the `#account-type-help` region is a two-card grid (one card per option, same Card tokens) spelling out Client vs Agency in plain words. Under the card is `Already registered? Log in`. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x1108 | after  | Post-pass desktop page, same card markup. The card stays at `max-w-md` so it is a true centred card on the wide page; the public header and footer draw the Anderson BI chrome around it. On ≥ sm, the Client / Agency help cards sit side-by-side under the select. |

## How it was checked

- `MIX_ENV=test mix test` — 3165 tests passed, 3 excluded.
- `MIX_ENV=test mix spex` — 766 spex pass, including every criterion under
  `test/spex/1_user_registration_and_account_creation/` (which drive the
  `#registration_form` by name).
- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/registration_test.exs`
  — 14 tests, including the new
  `renders in Layouts.content as an Anderson BI centred card with the logo`
  test. That test fails on the pre-pass file (confirmed by temporarily
  reverting `lib/metric_flow_web/live/user_live/registration.ex` to the
  issue-as-handed-in content: the assertion
  `assert html =~ "rounded-box border border-neutral bg-base-200"` is the
  one that trips — the pre-pass registration body has no card at all).
- `agent-browser` (headless Chromium) drove `/users/register` logged out on
  `MIX_ENV=dev PORT=4098 DATABASE_NAME=metric_flow_pddp mix phx.server`.
  At each viewport the driver read back
  `window.liveSocket && liveSocket.isConnected() === true`,
  `location.pathname === "/users/register"`, and
  `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered:
`google-register`, `data-login-method="google"`, `registration_form`,
`account-type-help`, and the `select[aria-describedby="account-type-help"]`
assertion in `registration_test.exs`. The `name` attributes on every form
input are unchanged (`user[email]`, `user[password]`, `user[account_name]`,
`user[account_type]`), so every spex that drives `#registration_form`
continues to submit the same payload. One new `data-role="referral-notice"`
only renders when `?ref=<token>` is in the URL; no test depends on its
absence.

## Referral path

The `?ref=<agency token>` path still links the new client account to the
referring agency. The LiveView still reads `params["ref"]` into
`@referral_token` on mount and calls
`MetricFlow.Agencies.associate_referred_account/2` after
`maybe_create_account/1` returns an `%Account{}`; the two tests under
`describe "registering through an agency referral link"` in
`registration_test.exs` continue to pass. The new referral notice in the
card makes the referred-client path visible to the persona in
`.code_my_spec/personas/agency-client-referred-customer/summary.md`.
