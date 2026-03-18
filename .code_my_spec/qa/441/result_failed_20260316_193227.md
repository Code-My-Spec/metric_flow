# QA Result

Story 441 — View All Metrics Dashboard

## Status

partial

## Scenarios

### Scenario 1 — Unauthenticated redirect (criterion 4068)

pass

Navigated to `http://localhost:4070/dashboards/1` without authentication. Browser redirected immediately to `http://localhost:4070/users/log-in`. Correct behavior.

Evidence: `screenshots/01_unauthenticated_redirect.png`

### Scenario 2 — Route discovery (criterion 4068)

fail

The BDD specs navigate to `/dashboard` (no trailing segment) but the router has no such route. Requesting `http://localhost:4070/dashboard` returns a `Phoenix.Router.NoRouteError` (HTTP 500 error page listing all available routes). The only dashboard route is `GET /dashboards/:id` mapped to `MetricFlowWeb.DashboardLive.Show`. There is no top-level `/dashboard` shortcut route.

After login, the QA owner (`qa@example.com`) was redirected to `http://localhost:4070/dashboards/1` — indicating a dashboard record with id=1 exists for this account. The QA member user (`qa-member@example.com`) was redirected to `/` after login (no default dashboard).

Evidence: `screenshots/02_dashboard_route_check.png`

### Scenario 3 — Onboarding state when no integrations connected (criterion 4074)

pass

Logged in as `qa-member@example.com` (no integrations) and navigated to `/dashboards/1`. The onboarding state rendered correctly:
- `data-role="onboarding-prompt"` container present
- H2 heading: "Connect Your Platforms"
- Body: "Connect your marketing and financial platforms to start seeing unified metrics, AI insights, and recommendations."
- "Connect Integrations" link pointing to `/integrations`
- No metrics data area rendered

Evidence: `screenshots/11_onboarding_state.png`

### Scenario 4 — Dashboard heading and page structure (criterion 4068)

pass

Logged in as `qa@example.com`. Dashboard page at `/dashboards/1` renders:
- H1: "All Metrics" — present
- Subtitle: "Your complete marketing and financial picture" — present
- `data-role="metrics-dashboard"` wrapper present

Evidence: `screenshots/13_dashboard_heading.png`, `screenshots/03_after_login_dashboard.png`

### Scenario 5 — Filter controls present with integrations (criteria 4070, 4071)

pass

The QA owner account has integrations connected. All three filter controls are present:
- `data-role="platform-filter"`: shows "All Platforms", "Google", "Google Ads" buttons
- `data-role="date-range-filter"`: shows "Last 7 Days", "Last 30 Days", "Last 90 Days", "All Time", "Custom Range" buttons
- `data-role="metric-type-filter"`: shows "All Types" (no metric types available since data is all zeros)

All 5 date range options from the acceptance criteria are present.

Evidence: `screenshots/05_filter_controls.png`

### Scenario 6 — Default date range excludes today (criterion 4072)

pass

On initial dashboard load, the date range display (`data-role="date-range"`) shows: "Showing 2026-02-03 – 2026-03-05 (today excluded — incomplete day)". Today is 2026-03-06. The end date 2026-03-05 is yesterday. The text explicitly includes "(today excluded — incomplete day)" satisfying the acceptance criterion. Default active button is "Last 30 Days" (`btn-primary`).

Evidence: `screenshots/03_after_login_dashboard.png`

### Scenario 7 — Dynamic filter updates (criterion 4073)

partial

Date range filters work correctly via LiveView in-process updates:
- Clicking "Last 7 Days": date range updated to "2026-02-27 – 2026-03-05", button gained `btn-primary`, LiveView remained alive — PASS
- Clicking "Last 90 Days": date range updated to "2025-12-06 – 2026-03-05" — PASS
- Clicking "All Time": button gained `btn-primary`, range updated — PASS
- Clicking "Custom Range": button gained `btn-primary`, falls back to default date range (no custom date picker rendered) — acceptable given current implementation

Platform filter: "Google Ads" filter works — clicking it sets `btn-primary` on that button and clears "All Platforms". However, clicking "Google" platform does not highlight the "Google" button — "All Platforms" retains `btn-primary`. This is a bug (see Issues).

Evidence: `screenshots/06_date_filter_7days.png`, `screenshots/07_date_filter_all_time.png`, `screenshots/08_platform_filter_google.png`, `screenshots/14_platform_filter_bug.png`

### Scenario 8 — Unified metrics area, no marketing/financial separation (criterion 4069)

pass

The dashboard renders all metrics in a single unified `data-role="metrics-area"` section. Stat cards visible for: Clicks, Spend, Impressions, Revenue, Conversions (raw metrics) and CPC, CTR, ROAS (derived metrics). All show 0.0 values (no synced data for this test account).

No `data-role="marketing-metrics-section"` element exists. No `data-role="financial-metrics-section"` element exists. The rendered HTML does not contain both "Marketing Metrics" and "Financial Metrics" as separate section headers.

Evidence: `screenshots/04_dashboard_full_state.png`

### Scenario 9 — Vega-Lite charts (criterion 4075)

pass

All chart containers use Vega-Lite:
- `data-role="metrics-data"` has `data-chart-type="vega-lite"`
- Each chart container has `data-role="vega-lite-chart"` and `phx-hook="VegaLite"`
- `data-spec` attribute contains valid Vega-Lite JSON spec with `"$schema":"https://vega.github.io/schema/vega-lite/v5.json"`
- No `canvas[data-chartjs]` elements found
- No `svg[data-d3-chart]` elements found
- No `chart.js` references in page HTML

Evidence: `screenshots/04_dashboard_full_state.png`

### Scenario 10 — Semantic attribution warning footnote

pass

`data-role="semantic-warning"` with `data-semantic-difference="attribution"` is present at the bottom of the metrics area. Contains text noting Google Ads 30-day click-through and Facebook Ads 7-day click / 1-day view-through attribution windows.

Evidence: `screenshots/10_semantic_warning.png`

## Evidence

- `screenshots/01_unauthenticated_redirect.png` — unauthenticated access to `/dashboards/1` redirects to login
- `screenshots/02_dashboard_route_check.png` — `/dashboard` route returns NoRouteError (no such route exists)
- `screenshots/03_after_login_dashboard.png` — owner logged in, dashboard full state with default Last 30 Days range
- `screenshots/04_dashboard_full_state.png` — full page showing all stat cards and chart containers
- `screenshots/05_filter_controls.png` — all three filter control rows visible
- `screenshots/06_date_filter_7days.png` — Last 7 Days filter active, date range updated
- `screenshots/07_date_filter_all_time.png` — All Time filter active
- `screenshots/08_platform_filter_google.png` — Google platform click, All Platforms still shows btn-primary (bug)
- `screenshots/09_ai_insights_panel.png` — AI insights panel opened via "AI Info" button on Clicks chart
- `screenshots/10_semantic_warning.png` — attribution warning footnote at page bottom
- `screenshots/11_onboarding_state.png` — member user sees onboarding prompt, no metrics area
- `screenshots/12_custom_range_selected.png` — Custom Range button selected state
- `screenshots/13_dashboard_heading.png` — H1 "All Metrics" heading and subtitle
- `screenshots/14_platform_filter_bug.png` — Google filter click, All Platforms remains btn-primary

## Issues

### No top-level `/dashboard` route — BDD specs reference a non-existent URL

#### Severity
HIGH

#### Scope
APP

#### Description
The story acceptance criteria and all 8 BDD spec files navigate to `/dashboard` but this route does not exist in the application. The router only defines `GET /dashboards/:id` mounted to `MetricFlowWeb.DashboardLive.Show`. Requesting `/dashboard` returns a `Phoenix.Router.NoRouteError` (HTTP 500 in dev mode).

The story describes an "All Metrics dashboard" as a primary top-level feature page — it should be accessible at a stable URL like `/dashboard` or `/metrics`. Requiring knowledge of a specific dashboard record `:id` contradicts the spec's intent of a unified platform-wide view.

Reproduced: navigate to `http://localhost:4070/dashboard` when authenticated — 500 error with "no route found for GET /dashboard".

### Platform filter active state broken for `:google` provider

#### Severity
MEDIUM

#### Scope
APP

#### Description
Clicking the "Google" platform filter button (`phx-value-platform="google"`) on the dashboard does not update the button active state. "All Platforms" retains its `btn-primary` class and the "Google" button remains `btn-ghost`, as if the `selected_platform` assign was not updated to `:google`.

By contrast, clicking "Google Ads" (`phx-value-platform="google_ads"`) correctly activates that button and deactivates "All Platforms".

The issue likely lies in the `filter_platform` event handler: `String.to_existing_atom("google")` may fail if `:google` atom does not exist in the BEAM atom table at the time of the event (returning an exception that silently resets the socket), or `Dashboards.get_dashboard_data/2` raises when given `platform: :google`, and Phoenix swallows the error without updating assigns.

Reproduced: log in as `qa@example.com`, navigate to `/dashboards/1`, click "Google" platform button — "All Platforms" button remains active with `btn-primary` class.

### BDD specs reference `:owner_with_integrations` shared given which is not defined

#### Severity
LOW

#### Scope
QA

#### Description
All 8 BDD spec files in `test/spex/441_view_all_metrics_dashboard/` use `given_ :owner_with_integrations` which is not defined in `test/support/shared_givens.ex`. Running `mix spex` on story 441 will fail at given step resolution before any assertions execute. This is a pre-existing issue also filed from story 439. The shared given needs to be added to `test/support/shared_givens.ex` to make the BDD test suite executable.

### Custom Range date picker not implemented

#### Severity
LOW

#### Scope
APP

#### Description
The date range filter shows a "Custom Range" button (`phx-value-range="custom"`) that can be selected, but no custom date range picker UI is rendered after selecting it. The range falls back to the same date range as the current selection (default). The acceptance criterion states "User can select date range: last 7 days, 30 days, 90 days, all time, custom" — selecting custom should allow the user to enter specific start/end dates. No date input fields or calendar widget appear when the custom option is chosen.

Reproduced: navigate to `/dashboards/1`, click "Custom Range" button — button becomes active but no date input UI appears, date range display does not change.
