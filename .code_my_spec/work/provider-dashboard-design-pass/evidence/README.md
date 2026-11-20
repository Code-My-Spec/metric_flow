# Evidence — provider-dashboard-design-pass

Four full-page PNGs of `/app/integrations/google_analytics/dashboard`
captured from this worktree's own dev server against the seeded
Anderson Retail Co. account (owner `client@example.com` from
`priv/repo/seeds.exs`, password `hello world!`). The `:google_analytics`
integration seeded on Anderson Retail renders the connected variant
(provider name, metric cards, controls, sync history) so both the
structural change (metric cards moved above the provider header and
the sync controls) and the token change (DESIGN.md Card panels,
`btn-brand-gradient` Sync Now, `border-neutral` dividers) land in one
frame at each width.

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page. Panels drawn with `mf-card` (an undefined class — no border, no background). The page leads with the `{provider} Dashboard` heading, connected email and "Last synced …" line, then the Sync Now row, and only then the metric cards. The Sync Now button is a flat daisyUI `btn btn-primary`, same weight as the Refresh ghost button next to it. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop — same invisible card chrome, same ordering (header → controls → metrics), same flat primary button. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page. The `data-role="key-metrics"` section leads with a compact `<h1>` plus `Connected` badge and then the metric cards (each a `rounded-box border border-neutral bg-base-200` panel). The sync controls live in their own Card below the metrics, with Sync Now as the `btn-brand-gradient rounded-box` primary, a DESIGN.md Secondary Refresh, and the connected email + last-synced caption flowing to the right at `sm:`. `document.documentElement.scrollWidth === 390` was read back before the shot (no horizontal overflow). |
| `after-1440.png`  | 1440x900  | after  | Same post-pass markup on desktop: metric cards grid is three across (`lg:grid-cols-3`), controls Card sits below, sync history uses DESIGN.md Card tokens with `border-neutral` dividers. |

## Capture environment

- Dev server started from this worktree with
  `PORT=4092 DATABASE_NAME=metric_flow_pddp MIX_ENV=dev
  CMS_MAIN_COPY=false sops exec-env envs/dev.enc.env mix phx.server`,
  against a freshly seeded `metric_flow_pddp` database (`mix ecto.create`
  then `mix ecto.migrate` then `mix run priv/repo/seeds.exs`).
  `CMS_MAIN_COPY=false` kept the worktree's Cloudflare tunnel disabled
  so the beam stayed on `127.0.0.1:4092`.
- `agent-browser` (headless Chromium) drove the login flow (filled
  `client@example.com` / `hello world!` into the `#password_email` /
  `#user_password` fields and pressed Enter), then navigated to
  `/app/integrations/google_analytics/dashboard`. Before each screenshot
  the driver read back `window.liveSocket && liveSocket.isConnected()`
  (true all four times), `location.pathname`
  (`/app/integrations/google_analytics/dashboard` all four times), and
  `document.documentElement.scrollWidth` (390 at the 390 viewport,
  1440 at the 1440 viewport).
- The before shots were captured after `git checkout HEAD --` on
  `lib/metric_flow_web/live/integration_live/provider_dashboard.ex`
  (restoring the issue-as-handed-in version at commit `99c0d5bd`) and
  letting Phoenix live-reload re-render the old markup —
  `!!document.querySelector('.mf-card')` read back `true` before both
  before shots. The file was restored to the post-pass edit before the
  after shots; the eval read back `mf=false` and
  `gradient=true` (the Sync Now button carries `btn-brand-gradient`)
  before both after shots.

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/integration_live/provider_dashboard_test.exs`
  passes 10 tests, including the new describe
  `"design pass: key metrics first in Anderson BI tokens"` that asserts
  `data-role="metric-card"` renders before both `data-role="sync-now"`
  and `data-role="sync-history-section"` in the HTML, that the Sync
  Now control matches `[data-role='sync-now'].btn-brand-gradient`, and
  that the pre-pass `mf-card` class is gone from the rendered output.
  The new describe fails against the pre-pass file (confirmed by
  reverting `provider_dashboard.ex` to HEAD: the metric-card/sync-now
  ordering assertion fails first, followed by the `btn-brand-gradient`
  and `mf-card` assertions).
- `mix spex` for every spex file that references a `data-role=` this
  page exposes — `[data-role='metric-card']`, `[data-role='sync-now']`,
  `[data-role='sync-history-section']`,
  `[data-role='reviews-section']`, `[data-role='no-review-data']`,
  `[data-role='rolling-review-metric-row']`,
  `[data-role='daily-review-count']`,
  `[data-role='running-review-total']`,
  `[data-role='rolling-review-average-rating']`,
  `[data-role='daily-location-metric']`, and
  `[data-role='empty-state']` — passes: the five spex files under
  `test/spex/39_calculate_rolling_review_metrics_from_review_table/`,
  the three under
  `test/spex/51_sync_google_business_profile_performance_metrics/`,
  `criterion_1009` under
  `test/spex/41_sync_google_business_profile_performance_metrics/`,
  `criterion_964` under `test/spex/36_sync_google_ads_data/`, the two
  under `test/spex/35_sync_google_analytics_4_data/`, the two under
  `test/spex/40_sync_google_search_console_data/`, and `criterion_749`
  under `test/spex/18_view_all_metrics_dashboard/`.
