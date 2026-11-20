# Evidence — user-settings-design-pass

Full-page PNGs of `/app/users/settings` captured as the seeded client user
of Anderson Retail Co. (`client@example.com`, dev password `hello world!`),
signed in against the shared `metric_flow_dev` database that
`priv/repo/seeds.exs` sets up.

At both widths the shot was taken after
`window.liveSocket && liveSocket.isConnected()` was true,
`location.pathname === "/app/users/settings"` was confirmed, and
`document.documentElement.scrollWidth === <viewport>` was read back. At
390, `scrollWidth === 390` — the page has no sideways scroll at a 390px
viewport. At 1440, `scrollWidth === 1440`.

The before shots were taken against the main worktree's running dev
server on port 4070, which is still rendering the pre-pass markup
(`lib/metric_flow_web/live/user_live/settings.ex` at commit `8c83ab98`,
identical to `main`). The after shots were taken from this worktree's own
`mix phx.server` (MIX_ENV=dev, PORT=4099) on the exact code committed in
this change. Both servers share the same seeded dev database, so the same
logged-in `client@example.com` session reached both URLs.

The seeded client user is not connected to CodeMySpec (the seeds do not
create an `:codemyspec` integration row for them), so `Danger zone` is
hidden in both after shots. Its structural correctness is covered by the
`:if={@codemyspec_connected}` guard in `render/1` and by the unit test
helpers that exercise the connected branch elsewhere in the test suite.

## Files

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page inside `Layouts.app`. The content column is a bare `mx-auto` wrapper around a `<.header>` + two stacked `<.form>`s separated by `divider` lines; the `Connected Services` block uses a hand-coded `border rounded-lg` row with the destructive `btn btn-sm btn-outline btn-error` Disconnect button sitting next to the connect/disconnect toggle, mixed in with the everyday settings. No card panels, no visible separation between the everyday email/password sections and the destructive action. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop. The forms and the connected-services row stretch the full width of the main column inside `Layouts.app`, still with only `divider` lines between the sections and the destructive Disconnect button still folded into the Connected Services row. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page in `Layouts.app`. Each settings section is its own `rounded-box border border-neutral bg-base-200` card with a short description (`data-role="settings-section"` on the Email, Password and Connected Services sections). Buttons use `btn-brand-gradient rounded-box` for the primary save/change actions. Form inputs stack one-per-row at 390; the MCP URL inside `#agent-access` uses `break-all` so the long `http://...` string wraps. `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900  | after  | Post-pass desktop page, same card markup, pinned to a centred `max-w-2xl` column inside `Layouts.app`. The main `App` shell (sidebar, top bar) draws the chrome around it. |

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/user_live/settings_test.exs`
  — 9 tests, including the new
  `email, password, and connected services each sit in a bg-base-200 card panel`
  test in the `renders each settings section as an Anderson BI card`
  describe block. That test fails on the pre-pass file (confirmed by
  temporarily restoring `lib/metric_flow_web/live/user_live/settings.ex`
  to the issue-as-handed-in content at commit `8c83ab98`: the assertion
  trips with `expected at least three settings-section cards, got 0` —
  the pre-pass has no `data-role="settings-section"` panels).
- The existing settings tests continue to pass: validating email, sending
  the email-change confirmation link, enforcing sudo mode, validating
  password, triggering password form submission, and the two email
  confirmation-token flash flows.
- Related session-management spex continue to pass:
  `test/spex/2_user_login_and_session_management/criterion_11_user_session_persists_across_browser_tabs_spex.exs`,
  `.../criterion_12_user_can_log_out_from_any_page_spex.exs`,
  `.../criterion_13_inactive_sessions_expire_after_a_reasonable_period_spex.exs`
  — each asserts `html =~ "Account Settings"` on the page's rendered HTML,
  which my new `<h1>Account Settings</h1>` still emits.
- `agent-browser` (headless Chromium) drove `/app/users/settings` as
  `client@example.com` on both servers. At each viewport the driver read
  back `location.pathname === "/app/users/settings"` and
  `document.documentElement.scrollWidth === <viewport>` before the shot.

## IDs and data-* preserved

Every id and data-* the old page carried is still rendered:
`#email_form` and `#password_form` (both used by
`test/metric_flow_web/live/user_live/settings_test.exs`), the hidden
`#hidden_user_email` input the password form carries for password managers,
the `#agent-access` MCP-instructions panel, and the
`phx-click="disconnect_codemyspec"` button with its
`data-confirm="Are you sure you want to disconnect CodeMySpec?"` guard. The
form `name` attributes on every input are unchanged, so the payloads POSTed
to `update_email`, `update_password` and `/app/users/update-password` keep
the same shape and the controller still sees the same keys. New data roles
(`data-role="settings-section"` on each card, `data-role="danger-zone"`
and `data-role="danger-zone-separator"` on the disconnect card and its
heading) are additive and keyed to the new structural assertions.
