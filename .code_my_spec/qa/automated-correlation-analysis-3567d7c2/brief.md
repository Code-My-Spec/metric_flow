# QA Story Brief

Story 447 — Automated Correlation Analysis. Tests the `/correlations` LiveView
(`MetricFlowWeb.CorrelationLive.Index`) in both its no-data empty state and its
data state (Raw mode table, sort, filter, Run Now, Smart mode, AI feedback).

## Tool

web (vibium MCP browser tools — `/correlations` is a session-authenticated LiveView)

## Auth

Run seeds first, then launch browser and log in via MCP:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials:
- Owner (has correlation data): `qa@example.com` / `hello world!`
- Member (no correlation data): `qa-member@example.com` / `hello world!`

To switch users: call `mcp__vibium__browser_delete_cookies()`, then navigate to `/users/log-in` and log in with the other credentials.

## Seeds

Run the base seeds first, then the story-specific seeds:

```bash
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_447.exs
```

The story seeds create:
- A completed `CorrelationJob` (goal metric: `revenue`, 90 data points, 90-day window)
- Five `CorrelationResult` rows for `qa@example.com`'s personal account:
  - `clicks` (Google Ads) — coefficient 0.82, lag 7 days — Strong
  - `spend` (Google Ads) — coefficient 0.74, lag 3 days — Strong
  - `impressions` (Facebook Ads) — coefficient 0.51, lag 14 days — Moderate
  - `income` (QuickBooks) — coefficient -0.38, lag 0 days (same day) — Weak
  - `sessions` (Google Analytics) — coefficient 0.29, lag 5 days — Weak

`qa-member@example.com` has no correlation data — use this account to test the no-data empty state.

## What To Test

### Scenario 1: No-data empty state (AC: 30+ days threshold, empty state message)

Log in as `qa-member@example.com` (no correlation data).

- Navigate to `http://localhost:4070/correlations`
- Capture screenshot: `no-data-state.png`
- Verify `[data-role="correlation-results"]` is present (wrapper always exists)
- Verify `[data-role="no-data-state"]` is visible
- Verify the page shows "No Correlations Yet" heading
- Verify the body text mentions "30 days" (minimum data threshold requirement)
- Verify the body text mentions "daily aggregated" or "daily" (daily data requirement)
- Verify the body text mentions "last calculated: never" or "need at least 30 days"
- Verify "Connect Integrations" button/link is present and points to `/integrations`
- Verify no raw-mode table is shown
- Confirms AC: minimum 30-day threshold explained to user

### Scenario 2: Page header and mode toggle present

Log in as `qa@example.com` (has correlation data). Navigate to `http://localhost:4070/correlations`.

- Capture screenshot: `page-header.png`
- Verify `h1` reads "Correlations"
- Verify subtitle reads "Which metrics drive your goal?"
- Verify `[data-role="mode-toggle"]` is present
- Verify `[data-role="mode-raw"]` button exists and has `.btn-primary` class (default mode)
- Verify `[data-role="mode-smart"]` button exists
- Verify `[data-role="run-correlations"]` button exists and is not disabled

### Scenario 3: Raw mode — correlation results table displayed (AC: correlations calculated, all metrics unified)

On the correlations page as `qa@example.com`:

- Verify `[data-role="raw-mode"]` section is visible
- Verify `[data-role="correlation-results"]` is present
- Verify `[data-role="correlation-summary"]` bar is shown
- Verify `[data-role="goal-metric"]` shows "Goal: revenue"
- Verify `[data-role="last-calculated"]` is present and shows a timestamp
- Verify `[data-role="data-window"]` shows a date range
- Verify `[data-role="data-points"]` shows "90 data points"
- Capture screenshot: `raw-mode-summary.png`
- Confirms AC: correlation results displayed, goal metric shown, last calculated visible

### Scenario 4: Results table — metric entries with coefficient and optimal lag (AC: lag 0-30, coefficient at optimal lag)

On the correlations page as `qa@example.com`:

- Verify `[data-role="results-table"]` is present
- Verify there are five `[data-role="correlation-row"]` rows
- Verify the "clicks" row (`[data-metric="clicks"]`) shows:
  - Coefficient value (expect `0.82`)
  - `[data-role="strength-badge"]` with text "Strong"
  - Lag cell with "7 days"
  - Platform badge with "Google Ads"
- Verify the "income" row (`[data-metric="income"]`) shows:
  - Negative coefficient (expect `-0.38`, colored differently — `.text-error`)
  - Lag cell shows "Same day" (optimal_lag == 0)
  - Platform badge with "QuickBooks"
- Capture screenshot: `results-table.png`
- Confirms AC: metric name and coefficient shown per entry; optimal lag displayed; lag range tested 0–30 days

### Scenario 5: Correlation results include all metric types without segregation (AC: financial and marketing treated the same)

On the correlations page as `qa@example.com`:

- Verify there is no `[data-role="marketing-correlations"]` section
- Verify there is no `[data-role="financial-correlations"]` section
- Verify financial metrics (e.g., `income` from QuickBooks) and marketing metrics (e.g., `clicks` from Google Ads) appear in the same unified table
- Capture screenshot: `unified-results.png`
- Confirms AC: correlation runs against all metrics, financial and marketing treated the same

### Scenario 6: Sorting the results table

On the correlations page as `qa@example.com`:

- Click the "Metric" column header button (`[data-sort-col="metric_name"]`)
- Verify `data-sort-active="true"` is set on the Metric header
- Verify the sort arrow appears
- Capture screenshot: `sorted-by-metric.png`
- Click the "Metric" header again
- Verify sort direction toggles (arrow changes direction)
- Click the "Lag" column header (`[data-sort-col="lag"]`)
- Verify `data-sort-active="true"` is set on the Lag header
- Capture screenshot: `sorted-by-lag.png`

### Scenario 7: Platform filter

On the correlations page as `qa@example.com`:

- Verify `[data-role="platform-filter"]` is present
- Verify "All Platforms" button has `.btn-primary` class (default active)
- Click the "Google Ads" filter button
- Verify only rows with `provider == :google_ads` are shown (expect 2 rows: clicks, spend)
- Capture screenshot: `filtered-google-ads.png`
- Click "All Platforms"
- Verify all 5 rows are shown again

### Scenario 8: Run Now button — insufficient data response

On the correlations page as `qa-member@example.com` (no data):

- Navigate to `http://localhost:4070/correlations`
- Click `[data-role="run-correlations"]`
- Verify an error flash appears: "Not enough data to run correlations. At least 30 days of metric data is required."
- Verify `[data-role="insufficient-data-warning"]` badge appears with "Insufficient data — 30 days of metrics required"
- Capture screenshot: `run-insufficient-data.png`
- Confirms AC: minimum data threshold enforced, error shown to user

### Scenario 9: Smart mode — opt-in card

On the correlations page as `qa@example.com`:

- Click `[data-role="mode-smart"]`
- Verify `[data-role="smart-mode"]` section is visible
- Verify the opt-in card is shown (before enabling AI suggestions)
- Verify "Smart Mode" heading is present
- Verify `[data-role="enable-ai-suggestions"]` button is present
- Capture screenshot: `smart-mode-optin.png`

### Scenario 10: Smart mode — enable AI suggestions and submit feedback

On the correlations page as `qa@example.com`, with Smart mode active:

- Click `[data-role="enable-ai-suggestions"]`
- Verify `[data-role="ai-suggestions-enabled"]` badge appears ("AI Suggestions enabled")
- Verify `[data-role="ai-recommendations"]` block is visible with "AI Recommendations" heading
- Verify `[data-role="ai-feedback-section"]` is present
- Verify `[data-role="feedback-helpful"]` and `[data-role="feedback-not-helpful"]` buttons are shown
- Capture screenshot: `smart-mode-enabled.png`
- Click `[data-role="feedback-helpful"]`
- Verify `[data-role="feedback-confirmation"]` appears with checkmark badge
- Verify feedback buttons are hidden
- Capture screenshot: `smart-mode-feedback-submitted.png`

### Scenario 11: Job running banner (visual state)

This scenario confirms the job-running UI exists in the rendered HTML. With `qa@example.com` on the correlations page and a correlation job running:

- Confirm `[data-role="run-correlations"]` button exists
- Note: the spinner/banner will only show if a job is actively in :pending or :running status. Verify the button is not disabled when no job is running (baseline check).
- Capture screenshot: `run-correlations-button.png`
- Confirms AC: daily calculation schedule — the banner and spinner text confirm the system runs correlation jobs

## Setup Notes

The seed script `priv/repo/qa_seeds_447.exs` creates correlation results by directly inserting records via the changeset (bypassing Oban workers) so that QA tests reflect completed data without needing an actual worker run. The job is seeded with `status: :completed` and a `completed_at` timestamp set to a few seconds before the seed runs.

The no-data state is tested using `qa-member@example.com`, which has no correlation data after the base seeds run.

The `/correlations` route requires authentication. Unauthenticated access redirects to `/users/log-in`.

The "daily after sync" acceptance criterion (AC 4109) is verified by the presence of the `[data-role="last-calculated"]` timestamp in the summary bar and the body text in the no-data state that mentions daily aggregated calculations. A scheduler test (that the cron actually fires) is out of scope for UI QA.

## Result Path

`.code_my_spec/qa/447/result.md`
