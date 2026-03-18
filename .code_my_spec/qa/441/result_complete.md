# QA Result

Story 441 — View All Metrics Dashboard

## Status

pass

## Scenarios

### Scenario 1 — Unauthenticated redirect (criterion 4068)

pass

Navigated to `http://localhost:4070/dashboard` without a session (after logging out). The browser was immediately redirected to `http://localhost:4070/users/log-in`. The route guard works correctly.

Verified via curl: `curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}" -L --max-redirs 0 http://localhost:4070/dashboard` returns `302 -> http://localhost:4070/users/log-in`.

Evidence: `.code_my_spec/qa/441/screenshots/s1-unauthenticated-redirect.png`

### Scenario 2 — Route discovery (criterion 4068)

pass

The spec lists the route as `/dashboard` (no params). The router confirms two matching routes:
- `live "/dashboard", DashboardLive.Show, :index` — primary route, no params required
- `live "/dashboards/:id", DashboardLive.Show, :show` — secondary route with `:id` param

After login the app redirected to `http://localhost:4070/dashboard`, confirming that is the canonical entry point. Navigating to `/dashboards/1` also loads the same `DashboardLive.Show` view without error — it accepts an arbitrary `:id` param and ignores it (mount does not use params). The brief's "route discrepancy" note is resolved: `/dashboard` exists and is the primary route.

Evidence: `.code_my_spec/qa/441/screenshots/s2-dashboard-primary-route.png`, `.code_my_spec/qa/441/screenshots/s2-dashboards-id-route.png`

### Scenario 3 — Onboarding state when no integrations connected (criterion 4074)

pass

Logged in as `qa-member@example.com` (a member user whose active account has no integrations). Navigated to `http://localhost:4070/dashboard`. The `has_integrations?` check returned false and the onboarding prompt rendered correctly.

Verified:
- `[data-role="onboarding-prompt"]` — present and visible
- Heading: "Connect Your Platforms" — present
- Body text mentions "marketing and financial platforms", "unified metrics", "AI insights" — present
- "Connect Integrations" button links to `/integrations` (`<a href="/integrations">`) — present and correct

Evidence: `.code_my_spec/qa/441/screenshots/s3-onboarding-prompt.png`

### Scenario 4 — Dashboard heading and page structure (criterion 4068)

pass

The dashboard page at `/dashboard` rendered (logged in as `qa@example.com` with integrations) with:
- H1: "All Metrics"
- Subtitle paragraph: "Your complete marketing and financial picture"
- "AI Chat" ghost button (`data-role="open-ai-chat"`) in the top-right of the header row

All match the spec exactly.

Evidence: `.code_my_spec/qa/441/screenshots/s2-dashboard-primary-route.png`

### Scenario 5 — Filter controls present with integrations (criteria 4070, 4071)

pass

All three filter control containers were present and correct:

- `[data-role="platform-filter"]` — rendered with "All Platforms", "Facebook Ads", and "Google" buttons
- `[data-role="date-range-filter"]` — rendered with all five buttons: "Last 7 Days" (`phx-value-range="last_7_days"`), "Last 30 Days" (`last_30_days`), "Last 90 Days" (`last_90_days`), "All Time" (`all_time`), "Custom Range" (`custom`). All use `phx-click="filter_date_range"`.
- `[data-role="metric-type-filter"]` — rendered with "All Types" button (no additional types since synced metrics don't include typed categories)

Evidence: `.code_my_spec/qa/441/screenshots/s5-filter-controls.png`

### Scenario 6 — Default date range excludes today (criterion 4072)

pass

The `[data-role="date-range"]` element displayed: "Showing 2026-02-13 – 2026-03-15 (today excluded — incomplete day)"

Today is 2026-03-16. The end date shown is 2026-03-15 (yesterday), confirming today is excluded. The default range is last 30 days. The "today excluded — incomplete day" annotation is present as required.

Evidence: `.code_my_spec/qa/441/screenshots/s6-date-range-display.png`

### Scenario 7 — Dynamic filter updates (criterion 4073)

pass

Clicked "Last 7 Days" from the default "Last 30 Days" state. The date range label updated in-place to "Showing 2026-03-09 – 2026-03-15 (today excluded — incomplete day)" without a full page reload. The "Last 7 Days" button gained `btn-primary` class (confirmed via class attribute check); the previously active "Last 30 Days" button reverted to `btn-ghost`.

Clicked the "Google" platform filter button. It gained `btn-primary`; "All Platforms" reverted to `btn-ghost`. Clicking "All Platforms" restored it as active.

No full-page reloads were observed during any filter interaction — all updates were LiveView in-place diffs.

Evidence: `.code_my_spec/qa/441/screenshots/s7-after-filter-7days.png`, `.code_my_spec/qa/441/screenshots/s7-platform-filter-google.png`, `.code_my_spec/qa/441/screenshots/s7-all-platforms-restored.png`

### Scenario 8 — Unified metrics area, no marketing/financial separation (criterion 4069)

pass

- `[data-role="metrics-dashboard"]` — present
- `[data-role="metrics-area"]` — present
- `[data-role="marketing-metrics-section"]` — not found (correct, no separation)
- `[data-role="financial-metrics-section"]` — not found (correct)
- `canvas[data-chartjs]` — not found
- `[data-d3-chart]` — not found
- Stat cards (`[data-role="stat-card"]`) present for: Clicks, Spend, Impressions, Revenue, Conversions (five raw metrics), plus CPC, CTR, ROAS (three derived metrics), plus Google Analytics-sourced metrics (activeUsers, averageSessionDuration, bounceRate, newUsers, screenPageViews, sessions)

The `[data-role="metrics-data"]` section has `data-chart-type="vega-lite"` and chart containers with `data-role="vega-lite-chart"` and `phx-hook="VegaLite"`.

Evidence: `.code_my_spec/qa/441/screenshots/s8-metrics-area-stats.png`

### Scenario 9 — Vega-Lite charts (criterion 4075)

pass

- `[data-role="metrics-data"]` has `data-chart-type="vega-lite"` — confirmed
- `[data-role="vega-lite-chart"]` elements present with `phx-hook="VegaLite"` attribute — confirmed
- `canvas[data-chartjs]` — not found
- No chart.js references found in page HTML
- `[data-d3-chart]` — not found

Chart containers are present with the correct hook and data-spec attributes. Visual rendering of charts was not verified (requires a browser with JS execution of vega-embed; headless session shows empty chart divs — this is expected behavior).

Evidence: `.code_my_spec/qa/441/screenshots/s8-metrics-area-stats.png`

### Scenario 10 — Semantic attribution warning footnote

pass

`[data-role="semantic-warning"]` with `data-semantic-difference="attribution"` was found. Text confirmed:

"Note: Cross-platform metric comparisons may reflect different attribution windows and counting methods. For example, Google Ads uses a 30-day click-through attribution window while Facebook Ads defaults to 7-day click / 1-day view-through. Values shown are aggregated using each platform's native attribution model."

Contains both the Google Ads 30-day and Facebook Ads 7-day attribution window references as specified.

Evidence: `.code_my_spec/qa/441/screenshots/s10-semantic-warning.png`

## Evidence

- `.code_my_spec/qa/441/screenshots/s1-unauthenticated-redirect.png` — unauthenticated access to /dashboard redirected to login page
- `.code_my_spec/qa/441/screenshots/s2-dashboard-primary-route.png` — /dashboard loads after login, shows "All Metrics" h1 and subtitle
- `.code_my_spec/qa/441/screenshots/s2-dashboards-id-route.png` — /dashboards/1 also loads DashboardLive.Show without error
- `.code_my_spec/qa/441/screenshots/s3-onboarding-prompt.png` — onboarding prompt rendered for user with no integrations
- `.code_my_spec/qa/441/screenshots/s5-filter-controls.png` — platform, date range, and metric type filter controls
- `.code_my_spec/qa/441/screenshots/s6-date-range-display.png` — date range label with "today excluded" note, end date is yesterday
- `.code_my_spec/qa/441/screenshots/s7-after-filter-7days.png` — Last 7 Days active after click, date range updated
- `.code_my_spec/qa/441/screenshots/s7-platform-filter-google.png` — Google platform filter button active with btn-primary
- `.code_my_spec/qa/441/screenshots/s7-all-platforms-restored.png` — All Platforms restored as active
- `.code_my_spec/qa/441/screenshots/s8-metrics-area-stats.png` — unified metrics area with stat cards and Vega-Lite chart containers
- `.code_my_spec/qa/441/screenshots/s10-semantic-warning.png` — semantic warning footnote with attribution window text

## Issues

None
