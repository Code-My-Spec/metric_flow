# QA Story Brief

Story 437 — Automated Daily Data Sync

Testing the `/integrations/sync-history` LiveView. This story is about how the system communicates daily automated sync behavior to users: schedule info, sync history entries, filter controls, date range display, real-time sync events, and error/retry visibility.

## Tool

web

## Auth

Log in as the QA owner user using the vibium MCP browser tools:

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

Run base seeds before testing. The seed script creates the two QA users and a team account. No additional story-specific seed data is required — the sync history page works with an empty history list.

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

Expected output ends with credentials:

```
Owner:    qa@example.com / hello world!
Member:   qa-member@example.com / hello world!
URL:      http://localhost:4070/users/log-in
```

## What To Test

### Scenario 1 — Page loads and renders core structure (AC: daily sync schedule at 2 AM UTC)

Navigate to `http://localhost:4070/integrations/sync-history` after login.

- Verify the page title is "Sync History"
- Verify the H1 heading "Sync History" is visible
- Verify the subtitle "View automated sync results and status" is present
- Verify `[data-role="sync-schedule"]` element is present
- Verify the schedule section contains "2:00 AM UTC" or "2 AM UTC"
- Verify the schedule section contains "Daily" or "daily"
- Verify a `.badge.badge-info` badge labelled "Daily" is visible
- Capture screenshot: `01_page_load.png`

### Scenario 2 — Schedule section communicates backfill and retry behavior (AC: backfill on first sync, retry up to 3 times)

On the same page:

- Verify the schedule section text mentions historical data backfill (contains "historical" or "backfill" or "all available")
- Verify the schedule section text mentions retry behavior (contains "retried" or "retry" or "3 times" or "3 time")
- Capture screenshot: `02_schedule_section.png`

### Scenario 3 — Financial and marketing providers mentioned in schedule section (AC: financial data stored alongside marketing metrics, sync retrieves metrics and financial data)

On the same page:

- Verify the schedule section text or full page mentions "QuickBooks" (financial provider)
- Verify the schedule section text or full page mentions marketing providers — any of: "Google Ads", "Facebook Ads", "Google Analytics"
- Verify the page does not have a separate `[data-role="financial-sync-history"]` section (unified list only)
- Verify the page does not have a separate `[data-role="marketing-sync-history"]` section
- Capture screenshot: `03_providers_coverage.png`

### Scenario 4 — Date range bar excludes today (AC: default date ranges exclude today)

On the same page:

- Verify `[data-role="date-range"]` element is present
- Verify the date range element contains yesterday's ISO date (e.g. `2026-03-05` if today is `2026-03-06`)
- Verify the date range element does NOT show today's date as the end date in a "through YYYY-MM-DD" or "- YYYY-MM-DD" format
- Verify the date range text contains "yesterday" or "incomplete day" or "today excluded"
- Capture screenshot: `04_date_range.png`

### Scenario 5 — Empty state when no sync history (AC: sync pulls data from all active integrations)

Navigate to the sync history page as the QA owner user (who has no connected integrations and no sync history by default after seeding):

- Verify `[data-role="sync-history"]` element is present
- Verify the empty state panel is shown: contains "No sync history yet."
- Verify `[data-sync-type="initial"]` badge with text "Initial Sync" is visible in the empty state
- Verify no `[data-role="sync-history-entry"]` elements are present
- Capture screenshot: `05_empty_state.png`

### Scenario 6 — Filter buttons are present and default state is "All" active

On the same page:

- Verify three filter buttons are visible: "All", "Success", "Failed"
- Verify `[data-role="filter-all"]` button has class `btn-primary` (active)
- Verify `[data-role="filter-success"]` button has class `btn-ghost` (inactive)
- Verify `[data-role="filter-failed"]` button has class `btn-ghost` (inactive)
- Capture screenshot: `06_filter_buttons.png`

### Scenario 7 — Filter button click toggles active state

Click the "Success" filter button:

- Click `[data-role="filter-success"]`
- Wait for LiveView update
- Verify `[data-role="filter-success"]` now has class `btn-primary`
- Verify `[data-role="filter-all"]` now has class `btn-ghost`
- Click `[data-role="filter-failed"]`
- Wait for LiveView update
- Verify `[data-role="filter-failed"]` now has class `btn-primary`
- Verify `[data-role="filter-success"]` now has class `btn-ghost`
- Click `[data-role="filter-all"]` to reset
- Capture screenshot: `07_filter_toggle.png`

### Scenario 8 — Unauthenticated access redirects to login (AC: auth required)

In a new browser session (clear cookies) or via curl:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history
```

- Verify the HTTP status code is 302 (redirect to login)

### Scenario 9 — Page mentions "metrics" and "financial data" in body text (AC: sync retrieves metrics, review data, and financial data)

On the authenticated sync history page:

- Verify the full page text contains "metrics" or "Metrics"
- Verify the full page text contains "financial" or "Financial" or "QuickBooks"
- Capture screenshot: `09_metrics_financial_mention.png`

### Scenario 10 — Page structure integrity check

On the sync history page:

- Verify H1 text is exactly "Sync History"
- Verify `[data-role="sync-schedule"]` is present
- Verify `[data-role="date-range"]` is present
- Verify `[data-role="sync-history"]` is present
- Verify `[data-role="filter-all"]`, `[data-role="filter-success"]`, `[data-role="filter-failed"]` are all present
- Capture full-page screenshot: `10_full_page.png`

## Setup Notes

This story is implemented by `MetricFlowWeb.IntegrationLive.SyncHistory` at `/integrations/sync-history`. The LiveView loads persisted sync history from `DataSync.list_sync_history/1` scoped to the current user. With freshly-seeded QA data (no connected integrations), the sync history will be empty — the empty state panel is tested directly.

The BDD specs also test real-time LiveView events (`{:sync_completed, payload}` and `{:sync_failed, payload}`) but those require sending messages to the LiveView PID directly, which is an ExUnit pattern. The browser-based tests here cover what a real user would observe through the UI. Real-time behavior (live event prepending) is best covered by the ExUnit spex tests rather than browser automation.

The `[data-role="sync-schedule"]` card in the source template describes daily timing (2:00 AM UTC), covered providers (Google Ads, Facebook Ads, Google Analytics, QuickBooks), backfill on first sync, and retry policy (up to 3 times with exponential backoff) — all in the static body text.

## Result Path

`.code_my_spec/qa/437/result.md`
