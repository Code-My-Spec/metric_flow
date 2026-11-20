# Evidence — forgot-password-design-pass

Full-page PNGs of `/users/forgot-password` captured logged-out against the
seeded `metric_flow_pddp` database (`priv/repo/seeds.exs`). The page is
public: no fixture login is required to reproduce.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned `true` and
`location.pathname === "/users/forgot-password"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` was read back before the
shot — the page has no sideways scroll at a 390px viewport. At 1440,
`document.documentElement.scrollWidth === 1440`.

The before shots were taken on the issue-as-handed-in file (commit
`812a3047`) against the main worktree's running dev server (port 4070),
which was still rendering the pre-pass markup. The after shots were taken
from this worktree's own `mix phx.server` (MIX_ENV=dev, port 4099,
`DATABASE_NAME=metric_flow_pddp`) on the exact code committed in this
change.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page inside `Layouts.app` (so the sidebar drawer and top bar are there) with a bare `rounded-2xl border-base-300 bg-base-100 p-6 shadow-xl` card centred by `min-h-[70vh] max-w-md`. No logo above the heading, a hand-coded `rounded-2xl` radius instead of the theme `rounded-box`, a `btn btn-primary` submit, and a bare `Back to log in` link. Nothing marks this as Anderson BI and the shell is the app shell, not the public one. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. Because the pre-pass uses `Layouts.app`, the full application sidebar is rendered beside the card on `lg:`, so a logged-out visitor looking for "email me a reset link" is shown a sidebar they cannot use. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.content`. The inline `/images/anderson-bi-logo.png` (`data-role="default-logo"`) sits above a centred `max-w-md` card drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`), matching the login card. The card contains, in order: the `#forgot-password-form` form with an Email input, and the brand-gradient `Send reset link` submit. Under the form is `Remembered it? Back to log in` linking to `/users/log-in` (keeps `id="back-to-login"`). `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop page, same card markup. The card stays at `max-w-md` so it is a true centred card on the wide page; the `Layouts.content` public header (same Anderson BI logo and nav as login/register) and footer draw the chrome around it. No app sidebar is rendered — the logged-out visitor is not shown app navigation they cannot use. |

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/password_reset_test.exs`
  — 5 tests, including the new
  `renders in Layouts.content as an Anderson BI centred card with the logo`
  test. That test fails on the pre-pass file (confirmed by temporarily
  reverting `lib/metric_flow_web/live/user_live/forgot_password.ex` to the
  issue-as-handed-in content: the assertion `assert html =~ "Privacy Policy"`
  is the one that trips — the pre-pass renders `Layouts.app`, whose shell
  has no Privacy/Terms footer).
- `agent-browser` (headless Chromium) drove `/users/forgot-password` logged
  out on both servers. At each viewport the driver read back
  `window.liveSocket && liveSocket.isConnected() === true`,
  `location.pathname === "/users/forgot-password"`, and
  `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered: the
`#forgot-password-form` form id (used by `password_reset_test.exs` and the
matching login-page `#forgot-password-link` assertion in `login_test.exs`
and criterion 9 spex) and the `#back-to-login` link id. The `name`
attributes on the email input are unchanged (`user[email]`), so the
`known and unknown emails receive the same response` test continues to
submit the same payload. A new inline `data-role="default-logo"` on the
Anderson BI logo above the card matches the login/registration pattern
(`Layouts.content` already carries one in its header; the inline one above
the card is the design-system-2 pattern for public auth pages).
