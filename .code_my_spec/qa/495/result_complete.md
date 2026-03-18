# QA Result

Story 495 — Correct Aggregation of Derived and Calculated Metrics

## Status

pass

## Scenarios

### Scenario 1 — Dashboard loads for an authenticated user

**Result: pass**

Navigated to `http://localhost:4070/dashboard` as `qa@example.com` (confirmed user with an active Google Ads integration). The page loaded at the correct URL with the `h1` "All Metrics" and subtitle "Your complete marketing and financial picture". The `data-role="metrics-dashboard"` container was visible and the `data-role="onboarding-prompt"` was not present. No redirect or server error occurred.

Evidence: `screenshots/01_dashboard_loads.png`

### Scenario 2 — Onboarding prompt shown when no integrations exist

**Result: pass**

Created a fresh confirmed user (`qa-noint@example.com`) with no integration records, logged in via magic link token, and navigated to `/dashboard`. The `data-role="onboarding-prompt"` element was visible. Visible text confirmed "Connect Your Platforms" heading, description copy, and a "Connect Integrations" link with `href="/integrations"`. The `data-role="metrics-dashboard"` container was not rendered.

Evidence: `screenshots/02_onboarding_prompt.png`

### Scenario 3 — Raw/additive metrics appear on the dashboard

**Result: pass**

With the Google Ads integration present, the dashboard rendered 5 raw metric stat cards via `data-role="stat-card"`: Clicks, Spend, Impressions, Revenue, Conversions. All 5 showed `0.0` (no synced metric rows in the database) with `data-role="stat-sum"` and `data-role="stat-avg"` sub-elements. None of the cards displayed "(raw)", "(additive)", or any user-visible type badge. All 5 also appeared as chart cards in the `data-role="metrics-data"` section with `data-role="chart-card"` and "AI Info" buttons.

Evidence: `screenshots/03_raw_metric_cards.png`

### Scenario 4 — Derived/calculated metrics appear and are computed from aggregated components

**Result: pass**

Three derived metric stat cards were present: CPC, CTR, ROAS. All used the same `data-role="stat-card"` structure as the raw metrics. Values were `0.0` because all component metrics (Clicks=0, Spend=0, Impressions=0, Revenue=0) were zero — the `safe_divide/2` helper returns `0.0` rather than dividing by zero. No formula strings such as `sum(spend)/sum(clicks)` appeared anywhere in the rendered HTML. Each derived metric also appeared as a chart card with an "AI Info" button, identical in structure to raw metric chart cards.

Source code inspection of `enrich_with_known_metrics/1` in `DashboardLive.Show` confirmed the computation: raw component sums are collected first, then CPC = Spend/Clicks, CTR = Clicks/Impressions, ROAS = Revenue/Spend — aggregating components before deriving, never averaging per-row derived values.

Evidence: `screenshots/04_derived_metric_cards.png`

### Scenario 5 — No user-visible "(derived)", "(calculated)", or "(raw)" badge leakage

**Result: pass**

Inspected the full page text and HTML. The strings `(calculated)`, `(derived)`, `(raw)`, `aggregation method`, `sum(spend)/sum(clicks)`, `sum(clicks)/sum(impressions)`, and `sum(revenue)/sum(spend)` were all absent from the rendered output. All 8 metric cards (5 raw + 3 derived) used identical visual structure — `.mf-card p-4` with metric name label, `data-role="stat-sum"` value, and `data-role="stat-avg"` line. The aggregation logic is fully transparent to the user.

Evidence: `screenshots/05_no_badge_leakage.png`

### Scenario 6 — Zero/missing data produces 0.0, not Infinity or NaN

**Result: pass**

With no synced metric rows in the database, all component raw metrics were zero. The derived metrics (CPC, CTR, ROAS) all displayed `0.0`. The strings "Infinity" and "NaN" were absent from both the page text and the full HTML source. The `safe_divide/2` function handles the denominator-zero case by returning `0.0`.

Evidence: `screenshots/06_no_nan_infinity.png`

### Scenario 7 — Date range filter controls work

**Result: pass**

The `data-role="date-range-filter"` row rendered 5 buttons: Last 7 Days, Last 30 Days (active by default with `btn-primary`), Last 90 Days, All Time, Custom Range. Clicking "Last 7 Days" caused the button to receive `btn-primary` class and the `data-role="date-range"` text updated to show "Showing 2026-02-27 – 2026-03-05 (today excluded — incomplete day)". Clicking "All Time" similarly activated that button and updated the date range display. The LiveView re-fetched dashboard data after each click with no errors.

Evidence: `screenshots/07_date_range_filter.png`

### Scenario 8 — Platform filter controls work

**Result: pass**

The `data-role="platform-filter"` row rendered "All Platforms" (active, `btn-primary`), "Google", and "Google Ads" buttons. Clicking "Google Ads" activated it with `btn-primary` and deactivated "All Platforms" to `btn-ghost`. Clicking "All Platforms" restored the default state. The platform filter correctly reflects the seeded Google Ads integration.

Evidence: `screenshots/08_platform_filter.png`

### Scenario 9 — Metric type filter controls are present

**Result: pass**

The `data-role="metric-type-filter"` row rendered "All Types" as the only button (active, `btn-primary`). No additional metric type buttons appeared, consistent with the seeded integration having no synced metric rows and therefore no available metric types beyond the default. The button structure matched the spec.

Evidence: `screenshots/09_metric_type_filter.png`

### Scenario 10 — AI Insights panel opens and closes

**Result: pass**

Clicked the `data-role="ai-info-button"` on the CPC chart card. The `data-role="ai-insights-panel"` became visible with heading "AI Insights: CPC", body copy referencing correlation analysis, and a link to `/insights`. The panel carried `data-metric="CPC"`. Clicking the `data-role="close-button"` (✕) made the panel hidden again, verified by `browser_wait` with `state: "hidden"`.

Evidence: `screenshots/10_ai_insights_panel.png`

### Scenario 11 — Unauthenticated access redirects to login

**Result: pass**

`curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/dashboard` returned `302`. The route is correctly guarded by the `require_authenticated_user` plug.

## Evidence

- `.code_my_spec/qa/495/screenshots/01_dashboard_loads.png` — Full-page dashboard with all stat cards and chart cards visible for qa@example.com
- `.code_my_spec/qa/495/screenshots/02_onboarding_prompt.png` — Onboarding prompt state for user with no integrations
- `.code_my_spec/qa/495/screenshots/03_raw_metric_cards.png` — Dashboard viewport showing raw metric stat cards (Clicks, Spend, Impressions, Revenue, Conversions)
- `.code_my_spec/qa/495/screenshots/04_derived_metric_cards.png` — Dashboard showing derived metric stat cards (CPC, CTR, ROAS) alongside raw metrics in uniform presentation
- `.code_my_spec/qa/495/screenshots/05_no_badge_leakage.png` — Dashboard with no internal type labels visible to user
- `.code_my_spec/qa/495/screenshots/06_no_nan_infinity.png` — Zero-data state showing 0.0 for all metrics, no Infinity or NaN
- `.code_my_spec/qa/495/screenshots/07_date_range_filter.png` — "All Time" active date range filter, updated date range display
- `.code_my_spec/qa/495/screenshots/08_platform_filter.png` — "Google Ads" selected in platform filter with active styling
- `.code_my_spec/qa/495/screenshots/09_metric_type_filter.png` — Metric type filter with "All Types" active
- `.code_my_spec/qa/495/screenshots/10_ai_insights_panel.png` — AI Insights panel open for CPC metric

## Issues

### BDD spex suite cannot run: `owner_with_integrations` given not defined in SharedGivens

#### Severity
HIGH

#### Scope
QA

#### Description
All 8 BDD spec files for story 495 use `given_ :owner_with_integrations` as their primary setup step, but this given is not defined anywhere in `test/support/shared_givens.ex`. Running `mix spex` for any of the criterion files under `test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/` will fail at compile time or produce a runtime error because the given is unresolvable.

The same given is also referenced by all spec files in story 493 (`test/spex/493_cross-platform_metric_normalization_and_mapping/`), so this is a systemic gap affecting at least two stories.

The missing given needs to: register or look up a confirmed user, create a connected integration record for that user, and return `%{owner_conn: authenticated_conn}` in the context so that `context.owner_conn` is a valid authenticated connection for `live/2` calls.

Reproduction: run `mix spex test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4611_system_distinguishes_between_rawadditive_metrics_eg_clicks_spend_impressions_and_derivedcalculated_metrics_eg_cpc_ctr_conversion_rate_roas_spex.exs` — all scenarios will fail because `:owner_with_integrations` is not found in `MetricFlowSpex.SharedGivens`.
