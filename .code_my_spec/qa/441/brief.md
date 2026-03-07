# QA Story Brief

Story 441 — View All Metrics Dashboard

## Tool

web (MCP browser automation via vibium)

## Auth

Log in using the seeded QA owner account via the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run the base QA seed script before testing:

```bash
cd /Users/johndavenport/Documents/github/metric_flow && mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner: `qa@example.com` / `hello world!`
- Member: `qa-member@example.com` / `hello world!`
- Team account: "QA Test Account"

No integrations are created by the seed script. Story 441 tests two states: the onboarding/empty state (no integrations connected) and the dashboard with integrations. The onboarding state is fully testable with seeds alone. Testing the full metrics dashboard state requires connected integrations — because the `Dashboards.has_integrations?/1` check in `mount/3` determines which view is rendered.

## Setup Notes

**Route discrepancy:** The BDD specs navigate to `/dashboard` but the actual router mounts `DashboardLive.Show` at `/dashboards/:id`. There is no `/dashboard` route in the application. The spec expects a dedicated top-level All Metrics route but none exists. Test `/dashboards/` paths (try `/dashboards/all` or navigate from the app nav) to discover the actual entry point, and document whether the route matches what the story specifies.

**`owner_with_integrations` given not implemented:** All spex files that test the dashboard with data reference `given_ :owner_with_integrations`, which is not defined in `test/support/shared_givens.ex` (known issue filed as `qa-439-bdd_spex_reference_owner_with_integration.md`). BDD spec execution will fail before any assertions. Browser testing of the onboarding state (no integrations) is fully testable. Testing the metrics-loaded state requires manually connecting integrations or adding the missing given.

**Default date range:** The `mount/3` sets `selected_date_range: :last_30_days`. The `render_date_range/1` helper always appends "(today excluded — incomplete day)" to the date range display.

## What To Test

### Scenario 1 — Unauthenticated redirect (criterion 4068)

- Navigate to `http://localhost:4070/dashboards/1` without logging in (use a fresh browser or clear cookies first)
- Expected: redirected to `/users/log-in`
- Screenshot: unauthenticated redirect

### Scenario 2 — Route discovery (criterion 4068)

- After logging in, navigate to `http://localhost:4070/dashboards/1`
- Check if the page loads or returns an error (the `:id` param is required, but no dashboard ID exists in seeds)
- Also try `http://localhost:4070/dashboard` to confirm it 404s or redirects
- Expected: document the actual route behavior and whether a top-level `/dashboard` route exists
- Screenshot: route response for both URLs

### Scenario 3 — Onboarding state when no integrations connected (criterion 4074)

- Log in as `qa@example.com`
- Navigate to any reachable dashboard URL (try `/dashboards/1`, `/dashboards/all`, or follow nav links from `/accounts`)
- If the page loads: look for `data-role="onboarding-prompt"` container
- Expected: heading "Connect Your Platforms", body text mentioning unified metrics and AI insights, a "Connect Integrations" link pointing to `/integrations`
- Screenshot: onboarding prompt state

### Scenario 4 — Dashboard heading and page structure (criterion 4068)

- If the dashboard page loads in any state:
- Verify the page has an H1 "All Metrics"
- Verify subtitle "Your complete marketing and financial picture" is visible
- Screenshot: page heading

### Scenario 5 — Filter controls present with integrations (criteria 4070, 4071)

- These tests require integrations to be present (`has_integrations? == true`)
- If integrations can be connected via the UI during the session, do so and then navigate to the dashboard
- Look for `data-role="platform-filter"`, `data-role="date-range-filter"`, `data-role="metric-type-filter"`
- Check date range buttons: "Last 7 Days", "Last 30 Days", "Last 90 Days", "All Time", "Custom Range"
- Each button should use `phx-click="filter_date_range"` and `phx-value-range` attribute
- Screenshot: filter controls visible

### Scenario 6 — Default date range excludes today (criterion 4072)

- With integrations connected and dashboard loaded:
- Look for `data-role="date-range"` element
- Verify the text contains "today excluded" or "incomplete day"
- Verify the end date shown is yesterday's ISO date (not today's)
- Screenshot: date range display text

### Scenario 7 — Dynamic filter updates (criterion 4073)

- With integrations connected and dashboard loaded:
- Click a date range filter button (e.g. "Last 7 Days")
- Verify the page updates without a full reload (LiveView in-place update)
- Verify the clicked button gains `btn-primary` class (active state)
- Click "All Platforms" then a specific platform filter button
- Screenshot: filter state before and after

### Scenario 8 — Unified metrics area, no marketing/financial separation (criteria 4069)

- With integrations connected:
- Verify presence of `data-role="metrics-dashboard"` wrapper
- Verify presence of `data-role="metrics-area"` unified section
- Verify NO elements with `data-role="marketing-metrics-section"` or `data-role="financial-metrics-section"`
- Verify stat cards with `data-role="stat-card"` show metric names like Clicks, Spend, Impressions, Revenue
- Screenshot: unified metrics area

### Scenario 9 — Vega-Lite charts (criterion 4075)

- With integrations connected:
- Verify `data-role="metrics-data"` section has `data-chart-type="vega-lite"` attribute
- Verify chart containers have `data-role="vega-lite-chart"` and `phx-hook="VegaLite"`
- Verify NO `canvas[data-chartjs]`, NO `chart.js` references, NO D3 elements with `data-d3-chart`
- Screenshot: chart cards with Vega-Lite containers

### Scenario 10 — Semantic attribution warning footnote

- With integrations connected:
- Verify `data-role="semantic-warning"` footnote is present
- Verify it contains text about attribution windows (Google Ads 30-day, Facebook Ads 7-day)
- Screenshot: footnote visible at bottom of metrics area

## Result Path

`.code_my_spec/qa/441/result.md`
