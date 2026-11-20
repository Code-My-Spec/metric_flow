# Evidence — agency-settings-design-pass

Full-page PNGs of `/app/agency/settings` captured as the seeded agency
owner `joel@example.com` (dev password `hello world!`) on the agency
account **Anderson the Fish** from `priv/repo/seeds.exs`, against the
shared `metric_flow_dev` database.

At each viewport the shot was taken after
`window.liveSocket && liveSocket.isConnected()` returned `true`,
`location.pathname === "/app/agency/settings"` was confirmed, the
active-account name span read back `"Anderson the Fish"`, and
`document.documentElement.scrollWidth === <viewport>` was read back. At
390, `scrollWidth === 390` — no sideways scroll on a 390px phone. At
1440, `scrollWidth === 1440`.

- **Before** shots were taken against the main checkout's running dev
  server on port 4070 (`/Users/johndavenport/cms-dogfood/metric_flow-prod`),
  which is on commit `070f208c` "issue agency-settings-design-pass: the
  issue as handed in" — the pre-pass version of
  `lib/metric_flow_web/live/agency_live/agency_settings.ex`.
- **After** shots were taken from this worktree's own `mix phx.server`
  on port 4099 against the same seeded `metric_flow_dev` database, on
  the exact code committed in this change. The post-pass page renders
  `<main data-role="agency-settings-root">`, which was asserted present
  before each after screenshot.

## Files

| File              | Viewport | State  | What it shows |
|-------------------|----------|--------|---------------|
| `before-390.png`  | 390x844  | before | Pre-pass phone page. Generic `<.header>` (small `text-lg` h1 "Agency Settings", grey subtitle) above the two section components. No eyebrow, no column cap, no explicit scroll guard. |
| `before-1440.png` | 1440x900 | before | Same pre-pass markup on desktop. The content column has no `max-w` cap, so the two card sections stretch across the whole main area. |
| `after-390.png`   | 390x844  | after  | Post-pass phone page. Content wrapped in `<main data-role="agency-settings-root" class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden">`. Eyebrow "Agency settings", single `h1` "Set who joins your agency and what your clients see", one-sentence lede that names the two cards, then the auto-enrollment and white-label Anderson BI cards (`rounded-box border border-neutral bg-base-200`). `scrollWidth === 390`. |
| `after-1440.png`  | 1440x900 | after  | Post-pass desktop. Same layout pinned to a centred `max-w-3xl` column inside the app shell so the two cards read as readable units instead of stretching across the full viewport. |

All four PNGs are real full-page browser screenshots taken with
`agent-browser screenshot --full` on headless Chromium.

## How it was checked

- `mix test test/metric_flow_web/live/agency_live/agency_settings_test.exs` — 5 pass (added in this change). The three structural tests (`agency-settings-root` wrapper with `max-w-*` and `overflow-x-hidden`, exactly one `h1` inside it, Anderson BI card tokens on each of the two section `data-role`s) fail against the pre-pass template and pass after the edit.
- `mix test test/metric_flow_web/live/agency_live` — 51 pass (covers `settings_test.exs` and `logo_upload_test.exs`, which hit both `/app/accounts/settings` and `/app/agency/settings`).
- `mix spex --pattern 'test/spex/4_agency_team_auto-enrollment/*_spex.exs'` — 14 pass.
- `mix spex --pattern 'test/spex/30_agency_white-label_configuration/*_spex.exs'` — 19 pass.

## IDs and `data-*` preserved

Every id and `data-*` attribute the pre-pass page carried is still rendered:

- Auto-enrollment card: `data-role="agency-auto-enrollment"`, `form#auto-enrollment-form`, `#auto-enrollment-domain-input`, `#auto-enrollment-default-role`, `data-role="auto-enrollment-domain-input"`, `data-role="auto-enrollment-default-role"`, `data-role="disable-auto-enrollment"`.
- White-label card: `data-role="agency-white-label"`, `form#white-label-form`, `#branding-logo-upload`, `#branding-subdomain`, `#branding-custom-domain`, `#branding-logo-url`, `#branding-primary-color`, `#branding-secondary-color`, `#branding-accent-color`, `#reset-branding`, `#save-branding`, `#pending-logo-preview`, `#branding-logo-url-preview`, `#branding-accent-preview`, `data-role="white-label-preview"`, `data-role="reset-white-label"`, `data-role="dns-verification"`, `data-role="verify-dns"`.
- Sidebar logos in `Layouts.app` (unchanged by this pass): `data-role="agency-logo"` and `data-role="default-logo"`.

## New `data-*` added

- `data-role="agency-settings-root"` on the `<main>` wrapper, so a test (and a reviewer) can target the Anderson BI column directly.
