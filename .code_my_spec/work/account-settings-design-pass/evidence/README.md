# account-settings-design-pass — evidence

Target: `/app/accounts/settings` as `joel@example.com` on the agency account
"Anderson the Fish" (seeded by `priv/repo/seeds.exs`).

## Files

- `before-390.png` — before the pass, 390px viewport, full page.
- `before-1440.png` — before the pass, 1440px viewport, full page.
- `after-390.png` — after the pass, 390px viewport, full page.
- `after-1440.png` — after the pass, 1440px viewport, full page.

## Capture method

All four shots are real `agent-browser screenshot --full` captures of the
rendered LiveView against the seeded `metric_flow_dev` database, signed in
as `joel@example.com` with the active account set to "Anderson the Fish",
so the agency-only sections (Agency Access, Auto-Enrollment, White-Label
Branding) render.

Before each shot the driver verified:

- `location.pathname === "/app/accounts/settings"`
- `document.querySelector('[data-role="current-account-name"]').textContent.trim() === "Anderson the Fish"`
- `window.liveSocket && liveSocket.isConnected() === true`
- `document.documentElement.scrollWidth === window.innerWidth` (390 at
  390px, 1440 at 1440px — the page never scrolls sideways at either
  width)

Sources:

- `before-*.png` came from the shared main-checkout server at
  `http://127.0.0.1:4070`, which was at commit `5f521c77` ("the issue as
  handed in") — the pre-pass state of `lib/metric_flow_web/live/account_live/settings.ex`
  and its two section components.
- `after-*.png` came from a dev-mode `mix phx.server` started in this
  worktree on `http://127.0.0.1:4099` against the same seeded
  `metric_flow_dev` database, with the worktree checked out at the
  design-pass commit on `issue/account-settings-design-pass`.
