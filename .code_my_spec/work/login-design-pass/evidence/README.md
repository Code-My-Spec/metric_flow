# Evidence — login-design-pass

Full-page PNGs of `/users/log-in` captured logged-out from this worktree's
own `mix phx.server` (MIX_ENV=dev, port 4097) running against the seeded
`metric_flow_pddp` database (`priv/repo/seeds.exs`). The page is public:
no fixture login is required to reproduce.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned `true` and
`location.pathname === "/users/log-in"` was confirmed. At 390,
`document.documentElement.scrollWidth === 390` was read back before the
shot — the page has no sideways scroll at a 390px viewport. At 1440,
`document.documentElement.scrollWidth === 1440`.

The before shots were taken on the issue-as-handed-in file (commit
`0976785c`) before any edits. The file was then rewritten; Phoenix
live-reload re-rendered the new markup, and the after shots were captured
on the exact code committed in this change.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page rendered in `Layouts.app` (the authenticated shell). Because the visitor is logged out there is no top bar, but the login card itself uses `rounded-2xl`, `border-base-300` and `bg-base-100` — a hard-coded 16px radius and the page token (not the card token), so the card dissolves into the page. One password form sits inside and a single "or" divider separates it from Google. There is no logo above the card and no second, labelled sign-in path, so the password route and any other route are not visually distinct. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. The card is wider but still drawn on `bg-base-100` with `rounded-2xl`, so it reads as a dialog on the same colour as the page. No logo, no public header/footer (the `Layouts.app` sidebar-less shell is used for logged-out users here, so the Anderson BI chrome never renders). |
| `after-390.png`   | 390x844   | after  | Post-pass phone page rendered in `Layouts.content` — the public layout, so the Anderson BI header (default-logo on the left, Log in / Register on the right) and the Privacy/Terms/Contact footer are present. The login card is centred (`mx-auto max-w-md`), drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`), and sits on the dark base-100 page. The `/images/anderson-bi-logo.png` logo (`data-role="default-logo"`) sits above "Log in". Inside the card the Google button is the first option; below the "or sign in with your email" divider the single password form `#login_form_password` carries the Email and Password inputs, the `Forgot password?` link, a gradient Primary "Log in with password" submit button, and — distinct beneath it with its own caption "No password? We'll email you a one-time sign-in link." — a Secondary-styled button `#email-sign-in-link[data-login-method="magic-link"]` that triggers `submit_magic` (reusing the email already typed into the form) so both password and magic-link routes are clear without adding a second form. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop page, same card markup. The card stays at `max-w-md` so it is a true centred card on the wide page; the public header and footer draw the Anderson BI chrome around it. |

## How it was checked

- `MIX_ENV=test mix test` — 3164 tests, all pass.
- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/login_test.exs` — 10 tests, including the new `renders in the public Layouts.content as a centred card on the dark theme, with the logo` test (which fails on the pre-pass file because `Layouts.app` emits no `"Privacy Policy"` footer) and the two magic-link button tests under `#email-sign-in-link`.
- `MIX_ENV=test mix spex test/spex/2_user_login_and_session_management/` — 12 pass, including criterion 9 (`User can log in with email and password`) and criterion 14 (`User can use remember me option for extended sessions`) both of which refute a separate `#login_form_magic` form and refute any other form on the page carrying an email input. The magic-link button lives inside `#login_form_password` and reuses the shared email, so neither refute fires.
- `MIX_ENV=test mix spex test/spex/3_multi-user_account_access/` — 20 pass.
- `MIX_ENV=test mix spex test/spex/6_agency_or_user_accepts_client_invitation/` — 14 pass.
- `agent-browser` (headless Chromium) drove `/users/log-in` logged out on `MIX_ENV=dev PORT=4097 DATABASE_NAME=metric_flow_pddp mix phx.server`. At each viewport the driver read back `window.liveSocket && liveSocket.isConnected() === true`, `location.pathname === "/users/log-in"`, and `document.documentElement.scrollWidth === <viewport>` before the shot, and confirmed `!!document.getElementById("email-sign-in-link") === true` at 390.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered: `google-login`, `data-login-method="google"`, `login_form_password`, `password_email`, `forgot-password-link`, `register-link`, `data-role="default-logo"`. The new control introduced is `#email-sign-in-link` with `data-login-method="magic-link"`; no existing test or spex refers to either and the spex that explicitly refute `#login_form_magic` still pass because that id is not used.
