# Evidence — confirmation-design-pass

Full-page PNGs of `/users/log-in/<token>` captured logged-out against the
seeded `metric_flow_dev` database (`priv/repo/seeds.exs`). The page needs a
valid, unused magic-link token for an unconfirmed user: a short script
(`.code_my_spec/work/confirmation-design-pass/make_token.exs`, discarded
before commit) registered a throwaway unconfirmed user and built a `login`
token for them through
`MetricFlow.Users.UserToken.build_email_token/2`, wrote the hashed row to
`users_tokens`, and printed the URL-safe encoded token. No email was sent —
the same path `extract_user_token`/`deliver_login_instructions` the tests
use ends up at.

The confirmation page auto-submits once the LiveView socket connects
(`phx-trigger-action={@trigger_submit}` on `#confirmation_form`, with
`trigger_submit: connected?(socket)` on mount) so that the unconfirmed user
does not have to click. To screenshot the page's rendered state (what the
user actually sees for the fraction of a second before the auto-submit),
the browser session installed an init-script that overrides
`HTMLFormElement.prototype.submit` to no-op for `#confirmation_form` and
`#login_form`. The HTML and LiveView re-render are otherwise untouched.

At both widths the shot was taken after
`location.pathname === "/users/log-in/<token>"` was confirmed and
`document.documentElement.scrollWidth === <viewport>` was read back. At
390, `scrollWidth === 390` — the page has no sideways scroll at a 390px
viewport. At 1440, `scrollWidth === 1440`.

The before shots were taken against the main worktree's running dev server
(port 4070), which is still rendering the pre-pass markup
(`lib/metric_flow_web/live/user_live/confirmation.ex` at commit `9eab4038`).
The after shots were taken from this worktree's own `mix phx.server`
(MIX_ENV=dev, port 4099, `DATABASE_NAME=metric_flow_dev`) on the exact code
committed in this change. Both servers share the same seeded dev database,
so a fresh magic-link token worked on both URLs.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page inside `Layouts.content`. The content column is a bare `mx-auto max-w-sm` wrapper: no inline Anderson BI logo above the card, a `<.header>` block with `Welcome <long email>`, and two full-width `btn btn-primary` / `btn btn-primary btn-soft` daisyUI buttons stacked with a hand-coded `alert alert-outline` tip below them. No card panel: the buttons sit directly on the page background. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. The `max-w-sm` wrapper leaves the content pinned left-of-centre at desktop widths and the buttons still sit on the page background with no card around them. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.content`. The inline `/images/anderson-bi-logo.png` (`data-role="default-logo"`) sits above a centred `max-w-md` card drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`), matching the login, forgot-password and reset-password cards. The heading reads `Confirm your account` with the user's email beneath it. The card contains, in order: the `#confirmation_form` form with the brand-gradient `Confirm and stay logged in` primary and the neutral `Confirm and log in only this time` secondary; and the password-tip panel in a `rounded-box border border-neutral bg-base-100` sub-panel. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop page, same card markup. The card stays at `max-w-md` so it is a true centred card on the wide page; the `Layouts.content` public header (same Anderson BI logo and nav as login/forgot-password/reset-password/register) and footer draw the chrome around it. |

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/confirmation_test.exs`
  — 8 tests, including the new
  `logged-out confirmation with a valid magic-link token renders the Anderson BI card and gradient confirm, not the old daisyUI shell`
  test in the `renders in Layouts.content as an Anderson BI centred card with the logo`
  describe block. That test fails on the pre-pass file (confirmed by
  temporarily reverting
  `lib/metric_flow_web/live/user_live/confirmation.ex` to the
  issue-as-handed-in content: the assertion
  `assert html =~ "rounded-box border border-neutral bg-base-200"` is the
  one that trips — the pre-pass does not wrap the buttons in a card).
- The existing confirmation_form / login_form spex tests continue to pass:
  `test/spex/1_user_registration_and_account_creation/criterion_515_verification_link_activates_the_account_spex.exs`
  and `criterion_520_user_lands_in_onboarding_already_logged_in_after_registering_spex.exs`.
- `agent-browser` (headless Chromium) drove `/users/log-in/<token>` logged
  out on both servers. At each viewport the driver read back
  `location.pathname === "/users/log-in/<token>"` and
  `document.documentElement.scrollWidth === <viewport>` before the shot.
  An init-script overrode `HTMLFormElement.prototype.submit` for
  `#confirmation_form` / `#login_form` so the page's auto-submit did not
  redirect before the screenshot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered:
`#confirmation_form` (used by
`test/metric_flow_web/live/user_live/confirmation_test.exs` and by the
spex criteria 515 and 520 above) and `#login_form` (used by the
confirmation_test "logs confirmed user in without changing confirmed_at"
test). The `name` attributes on the form inputs are unchanged
(`user[token]` and the `user[remember_me]="true"` button name), so the
payload submitted to `/users/log-in?_action=confirmed` is unchanged and
the controller still sees the same shape. A new inline
`data-role="default-logo"` on the Anderson BI logo above the card matches
the login, forgot-password and reset-password pattern (`Layouts.content`
already carries one in its header; the inline one above the card is the
design-system-2 pattern for public auth pages).
