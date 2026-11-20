# Evidence — reset-password-design-pass

Full-page PNGs of `/users/reset-password/<token>` captured logged-out against
the seeded `metric_flow_dev` database (`priv/repo/seeds.exs`). The page needs
a valid, unused reset-password token: a short script built one for
`client@example.com` through `MetricFlow.Users.UserToken.build_email_token/2`,
wrote the hashed row to `users_tokens`, and printed the URL-safe encoded
token. No email was sent — same path the
`extract_user_token`/`deliver_password_reset_instructions` helper the tests
use ends up at.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned `true` and
`location.pathname === "/users/reset-password/<token>"` was confirmed. At
390, `document.documentElement.scrollWidth === 390` was read back before the
shot — the page has no sideways scroll at a 390px viewport. At 1440,
`document.documentElement.scrollWidth === 1440`.

The before shots were taken against the main worktree's running dev server
(port 4070), which is still rendering the pre-pass markup
(`lib/metric_flow_web/live/user_live/reset_password.ex` at commit `9a6b304e`).
The after shots were taken from this worktree's own `mix phx.server`
(MIX_ENV=dev, port 4099, `DATABASE_NAME=metric_flow_dev`) on the exact code
committed in this change. Both servers share the same seeded dev database,
so the same reset-password token works on both URLs.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page inside `Layouts.app` (so the sidebar drawer and top bar frame the card for a logged-out visitor). The card is a hand-coded `rounded-2xl border-base-300 bg-base-100 p-6 shadow-xl`, centred by `min-h-[70vh] max-w-md px-4 py-10`. No logo above the heading, a hand-coded `rounded-2xl` radius instead of the theme `rounded-box`, a `btn btn-primary` submit, a bare `Back to log in` link. The shell is the app shell, not the public one. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. Because the pre-pass uses `Layouts.app`, the full application sidebar is rendered beside the card on `lg:`, so a logged-out visitor completing a password reset is shown AI Chat / All Data / Correlations / Integrations / Reports / Dashboards / Insights / Goals / Accounts navigation they cannot use. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.content`. The inline `/images/anderson-bi-logo.png` (`data-role="default-logo"`) sits above a centred `max-w-md` card drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`), matching the login and forgot-password cards. The card contains, in order: the `#reset-password-form` form with New password and Confirm new password inputs, and the brand-gradient `Reset password` submit. Under the form is `Remembered it? Back to log in` linking to `/users/log-in` (keeps `id="back-to-login"`). `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop page, same card markup. The card stays at `max-w-md` so it is a true centred card on the wide page; the `Layouts.content` public header (same Anderson BI logo and nav as login/forgot-password/register) and footer draw the chrome around it. No app sidebar is rendered — the logged-out visitor is not shown app navigation they cannot use. |

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/password_reset_test.exs`
  — 6 tests, including the new
  `logged-out reset-password with a valid token renders the Anderson BI card and gradient submit, not the old daisyUI shell`
  test in the `renders in Layouts.content as an Anderson BI centred card with the logo`
  describe block. That test fails on the pre-pass file (confirmed by
  temporarily reverting
  `lib/metric_flow_web/live/user_live/reset_password.ex` to the
  issue-as-handed-in content: the assertion `assert html =~ "Privacy Policy"`
  is the one that trips — the pre-pass renders `Layouts.app`, whose shell
  has no Privacy/Terms footer).
- `agent-browser` (headless Chromium) drove `/users/reset-password/<token>`
  logged out on both servers. At each viewport the driver read back
  `window.liveSocket && liveSocket.isConnected() === true`,
  `location.pathname === "/users/reset-password/<token>"`, and
  `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered:
`#reset-password-form` (used by `password_reset_test.exs` for the
`reset link changes password once and revokes existing sessions` and
`mismatched confirmation leaves the token usable` tests) and `#back-to-login`.
The `name` attributes on the password inputs are unchanged
(`user[password]`, `user[password_confirmation]`), so the submit payload is
unchanged and `reset_user_password/2` still gets the same shape. A new
inline `data-role="default-logo"` on the Anderson BI logo above the card
matches the login and forgot-password pattern (`Layouts.content` already
carries one in its header; the inline one above the card is the
design-system-2 pattern for public auth pages).
