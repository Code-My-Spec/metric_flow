# QA Story Brief

Story 495 — Correct Aggregation of Derived and Calculated Metrics

## Tool

web (Vibium MCP browser tools for the `/dashboard` LiveView page)

## Auth

Run seeds first (see Seeds section), then log in via the browser:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

The seed script creates a confirmed user that can log in with password. No integration records are seeded by the base script — the dashboard will initially show the onboarding prompt. A connected integration is needed to reach the dashboard state; see Seeds below.

## Seeds

Run the base seeds to create the QA user:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

The base seeds create `qa@example.com` (owner, confirmed) but do not create any integration records. The `/dashboard` route checks `Dashboards.has_integrations?/1` and renders the onboarding prompt when no integrations exist.

To reach the full dashboard state (metrics, filter controls, stat cards, charts), an integration record is required. Run the following Elixir snippet once via `mix run -e` to insert a Google integration for the QA user:

```bash
mix run -e '
  alias MetricFlow.{Repo, Users}
  alias MetricFlow.Integrations.Integration
  user = Users.get_user_by_email("qa@example.com")
  if user do
    import Ecto.Query
    existing = Repo.one(from i in Integration, where: i.user_id == ^user.id and i.provider == :google_ads, limit: 1)
    if is_nil(existing) do
      %Integration{}
      |> Integration.changeset(%{
           user_id: user.id,
           provider: :google_ads,
           access_token: "qa_test_token",
           refresh_token: "qa_test_refresh",
           expires_at: DateTime.add(DateTime.utc_now(), 86400, :second),
           granted_scopes: ["https://www.googleapis.com/auth/adwords"],
           provider_metadata: %{"selected_accounts" => ["QA-001"]}
         })
      |> Repo.insert!()
      IO.puts("Integration created")
    else
      IO.puts("Integration already exists")
    end
  else
    IO.puts("User not found — run qa_seeds.exs first")
  end
'
```

After this, the dashboard at `/dashboard` will show the full metrics state with stat cards, date-range filters, platform filters, and chart sections.

Note: The BDD specs use `given_ :owner_with_integrations` which is not yet defined in `test/support/shared_givens.ex`. This is a QA infrastructure gap — the spex test suite will fail until that given is added. The browser-based tests below cover the same acceptance criteria independently.

## What To Test

### Scenario 1 — Dashboard loads for an authenticated user (AC: all criteria baseline)

- Navigate to `http://localhost:4070/dashboard` while logged in as `qa@example.com`
- Expected: page loads without a redirect or error, shows "All Metrics" heading
- Screenshot: `01_dashboard_loads.png`

### Scenario 2 — Onboarding prompt shown when no integrations exist (AC: AC8 display parity — raw and derived metrics display identically when absent)

- Log in with a fresh user that has no integrations (or delete the integration, then reload)
- Expected: `data-role="onboarding-prompt"` visible, "Connect Your Platforms" heading present, "Connect Integrations" link pointing to `/integrations`
- Screenshot: `02_onboarding_prompt.png`

### Scenario 3 — Raw/additive metrics appear on the dashboard (AC: AC1 system distinguishes raw vs derived)

- With an integration present, navigate to `/dashboard`
- Expected: stat cards for Clicks, Spend, Impressions, Revenue, Conversions are visible in the summary stats grid (`data-role="stat-card"`)
- Expected: these are shown as plain numeric cards without any "(raw)" or "(additive)" user-visible badge
- Screenshot: `03_raw_metric_cards.png`

### Scenario 4 — Derived/calculated metrics appear on the dashboard (AC: AC1, AC2 — derived metrics defined by formula)

- With an integration present, navigate to `/dashboard`
- Expected: stat cards for CPC, CTR, and ROAS are present in the summary stats grid
- Expected: CPC value = total Spend / total Clicks (not an average of per-row CPC values)
- Expected: CTR value = total Clicks / total Impressions
- Expected: ROAS value = total Revenue / total Spend
- Expected: none of the cards expose formula strings like `sum(spend)/sum(clicks)` in visible text
- Screenshot: `04_derived_metric_cards.png`

### Scenario 5 — Derived metrics do not display "(derived)", "(calculated)", or "(raw)" user-visible badges (AC: AC8 transparent aggregation logic)

- Inspect the stat cards on the dashboard
- Expected: no text matching `(calculated)`, `(derived)`, `(raw)`, or `aggregation method` visible to the user
- Expected: the "Avg:" line under each stat card shows `data-role="stat-avg"` — verify derived metrics (CPC, CTR, ROAS) show the same card structure as raw metrics (Clicks, Spend, etc.)
- Screenshot: `05_no_badge_leakage.png`

### Scenario 6 — Derived metrics show 0 (not Infinity or NaN) when component data is zero or missing (AC: AC7 — missing data reflected as gap, not incorrect value)

- On the dashboard when seed data has no synced metric rows (zero-value components)
- Expected: CPC, CTR, ROAS stat cards show `0` or `0.0` as their value, not `Infinity` or `NaN`
- Check page HTML for the strings "Infinity" and "NaN" — neither should be present
- Screenshot: `06_no_nan_infinity.png`

### Scenario 7 — Date range filter controls are present (AC: AC3 — aggregating across time periods)

- On the dashboard, verify the date-range filter row is visible (`data-role="date-range-filter"`)
- Expected: buttons for "Last 7 Days", "Last 30 Days", "Last 90 Days", "All Time", "Custom Range" are rendered
- Click "Last 7 Days" button — expected: dashboard reloads data, "Last 7 Days" button gets `btn-primary` class, date range display updates
- Click "All Time" button — expected: similar active-state toggle, date range display shows "all available data" message
- Screenshot: `07_date_range_filter.png`

### Scenario 8 — Platform filter controls are present (AC: AC4 — aggregating across multiple platforms)

- On the dashboard, verify the platform filter row is visible (`data-role="platform-filter"`)
- Expected: "All Platforms" button is active (has `btn-primary` class) by default
- If more than one integration exists, platform buttons should appear for each
- Click "All Platforms" — expected: dashboard remains on the all-platforms view
- Screenshot: `08_platform_filter.png`

### Scenario 9 — Metric type filter controls are present (AC: AC1 distinction between raw and derived)

- On the dashboard, verify the metric type filter row is visible (`data-role="metric-type-filter"`)
- Expected: "All Types" button present and active by default
- Screenshot: `09_metric_type_filter.png`

### Scenario 10 — AI Insights panel opens and closes (not a core AC but validates dashboard integrity)

- Click the "AI Info" button (`data-role="ai-info-button"`) on any chart card
- Expected: `data-role="ai-insights-panel"` becomes visible with the correct metric name in the heading
- Click the close button (`data-role="close-button"`)
- Expected: panel disappears
- Screenshot: `10_ai_insights_panel.png`

### Scenario 11 — Unauthenticated access redirects to login (AC: all criteria — auth guard)

- Use `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/dashboard`
- Expected: `302` (redirect to `/users/log-in`)

## Setup Notes

The `enrich_with_known_metrics/1` private function in `DashboardLive.Show` is the core implementation for this story. It:
1. Adds zero-value stat cards for any known raw metrics not returned by the data layer
2. Derives CPC, CTR, and ROAS by summing the component raw metric values first, then dividing
3. Uses `safe_divide/2` which returns `0.0` (not `Infinity`/`NaN`) when the denominator is zero or nil

The BDD specs are oriented around the dashboard HTML output and use broad string-matching assertions. The browser tests here cover the same intent with visual evidence.

Known gap: `given_ :owner_with_integrations` is referenced in all 8 BDD spec files but is not defined in `test/support/shared_givens.ex`. Running `mix spex` for story 495 will produce a compile error or runtime failure on every scenario until this given is added. File a `qa` scope issue in the result if confirmed.

## Result Path

`.code_my_spec/qa/495/result.md`
