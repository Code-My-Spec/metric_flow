# QA Story Brief

Story 493 — Cross-Platform Metric Normalization and Mapping

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind session auth)

## Auth

Run seeds first (see Seeds section), then log in via the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials: `qa@example.com` / `hello world!`

To verify auth succeeded, confirm the URL is not `/users/log-in` after the click.

## Seeds

Run the base QA seeds before testing. The seeds create the `qa@example.com` owner user and the "QA Test Account":

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

The dashboard story requires at least one integration to be connected — otherwise the LiveView renders an onboarding prompt instead of the metrics dashboard. The `owner_with_integrations` shared given used by the BDD specs creates an integration via `MetricFlowTest.IntegrationsFixtures.integration_fixture/1` against a test user. For browser-based QA, you need an integration attached to the `qa@example.com` user's account. Add an integration seed after the base seeds:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run -e '
  user = MetricFlow.Users.get_user_by_email("qa@example.com")
  scope = MetricFlow.Users.Scope.for_user(user)
  account = MetricFlow.Accounts.get_default_account(scope)
  account_scope = MetricFlow.Users.Scope.for_user(user, account)
  {:ok, _} = MetricFlow.Integrations.create_integration(account_scope, %{
    provider: :google_ads,
    status: :active,
    access_token: "qa-token",
    account_ids: ["123456789"]
  })
  IO.puts("Integration created")
'
```

If the above fails (provider or field names differ), check `MetricFlow.Integrations` context and `test/support/fixtures/integrations_fixtures.ex` for the correct shape, then adjust accordingly and note any discrepancy as a `qa` scope issue.

## What To Test

All tests target `http://localhost:4070/dashboard` (the `MetricFlowWeb.DashboardLive.Show` LiveView). Screenshot at each key state to `/Users/johndavenport/Documents/github/metric_flow/.code_my_spec/qa/493/screenshots/`.

### AC 4602 — Canonical metric taxonomy displayed (clicks, spend, impressions, conversions)

- Navigate to `http://localhost:4070/dashboard`
- Screenshot the full dashboard
- Verify the page renders the metrics dashboard section (`[data-role="metrics-dashboard"]`), not the onboarding prompt (`[data-role="onboarding-prompt"]`)
- Verify stat cards are visible with `[data-role="stat-card"]` elements
- Verify the canonical metric names appear: "Clicks", "Spend", "Impressions", "Conversions" — check visible text in stat card labels and chart headers
- Verify derived metrics appear: "CPC", "CTR", "ROAS"

### AC 4603 — Platform integrations define mappings; canonical names used (not raw platform names)

- On the dashboard, verify "clicks" or "Clicks" appears as a stat card or chart heading — not "Link Clicks" as a standalone canonical metric
- Check that `[data-canonical-metric='link_clicks']` does NOT exist in the DOM
- Look for platform references — the filter buttons or chart data should mention "Google" or the connected provider name
- Screenshot the platform filter bar (`[data-role="platform-filter"]`)

### AC 4604 — Platform-specific metrics are labeled and visually separated

- On the dashboard, scroll to the "Platform-Specific Metrics" section
- Verify `[data-role="platform-specific-metrics-section"]` exists
- Verify the section heading "Platform-Specific Metrics" is visible
- If any platform-specific stat cards are shown, verify they carry `[data-metric-type="platform_specific"]` and `[data-canonical="false"]` attributes
- Verify the "Platform-Specific" badge text appears on any such cards
- Screenshot the platform-specific section
- If no platform-specific metrics exist, verify the fallback text "No platform-specific metrics detected. All synced metrics map to the canonical taxonomy." is shown

### AC 4605 — Users can view which platform metrics map to canonical metrics

- On the dashboard, verify canonical metric names are displayed alongside platform context
- Navigate to `http://localhost:4070/integrations`
- Screenshot the integrations page
- Verify the page loads without error (not redirected)
- Verify the connected platform (e.g., "Google" or "google") is listed on the integrations page

### AC 4606 — Mapped metrics aggregated across platforms using canonical names

- On the dashboard, verify aggregated totals appear under canonical stat cards for "Clicks" and "Spend"
- Verify `[data-canonical-metric='link_clicks']` does NOT appear as a canonical aggregation label
- Verify the platform filter bar is present and lists at least one platform besides "All Platforms"
- Screenshot the stats grid

### AC 4607 — Side-by-side comparison of the same metric across platforms

- On the dashboard, look for any cross-platform breakdown or comparison: check for `[data-role="platform-comparison"]`, or both "Google" and "Clicks" appearing together in page text
- Click a platform-specific button in `[data-role="platform-filter"]` if one is available, screenshot the filtered view
- Verify that "Link Clicks" is not attributed under `[data-canonical-metric="spend"]`

### AC 4608 — Semantic difference warnings / footnotes surfaced

- On the dashboard, scroll to the bottom of the metrics area
- Verify the semantic warning footnote is present: `[data-role="semantic-warning"]` with `data-semantic-difference="attribution"`
- Verify the footnote contains text referencing attribution windows, e.g., "30-day" or "7-day" or "attribution"
- Screenshot the footnote area

### AC 4609 — New platform integrations don't break existing canonical definitions

- On the integrations page (`http://localhost:4070/integrations`), verify the already-connected platform is shown
- Return to the dashboard and confirm canonical metric names ("Clicks", "Spend", "Impressions") are still present
- Verify `[data-canonical-metric="link_clicks"]` does not appear as a canonical label

### AC 4610 — Derived metrics (CPC, CTR, ROAS) work automatically across platforms

- On the dashboard, verify "CPC" appears in a stat card label or chart heading
- Verify "CTR" appears similarly
- Verify "ROAS" appears similarly
- Verify none of these show `[data-canonical-metric="action_link_click_cost"]` or `[data-canonical-metric="cost_per_action_type"]`
- Screenshot the stat cards area showing all derived metrics

### Auth guard check

- Quit browser and relaunch without logging in
- Navigate directly to `http://localhost:4070/dashboard`
- Verify the user is redirected (lands on `/users/log-in`, not the dashboard)
- Screenshot the redirect result

## Result Path

`.code_my_spec/qa/493/result.md`

## Setup Notes

The dashboard LiveView (`MetricFlowWeb.DashboardLive.Show`) renders two very different pages depending on whether the authenticated user's account has at least one integration. With no integrations it shows `[data-role="onboarding-prompt"]`; with integrations it shows `[data-role="metrics-dashboard"]`. All acceptance criteria for this story require the metrics dashboard view, so the integration seed above is mandatory before testing.

The canonical taxonomy is hardcoded in the LiveView module as `@known_raw_metrics ["Clicks", "Spend", "Impressions", "Revenue", "Conversions"]` and `@known_derived_metrics` for CPC, CTR, and ROAS. These are always shown as stat cards even when there is no real synced data (zeroed out). So most canonical taxonomy checks will pass as long as an integration exists and the dashboard renders.

The semantic warning footnote (`[data-role="semantic-warning"]`) is always rendered in the metrics dashboard section regardless of data. It contains text about 30-day and 7-day attribution windows.

The "Platform-Specific Metrics" section (`[data-role="platform-specific-metrics-section"]`) always renders; it shows a "No platform-specific metrics detected" message when all synced metrics map to canonical names.
