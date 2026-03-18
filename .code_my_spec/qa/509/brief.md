# QA Story Brief

Story 509: Sync Google Analytics 4 Data

The acceptance criteria for this story cover backend GA4 sync mechanics (API endpoint,
chunked requests, metric taxonomy, backfill, zero-value records, sampling detection,
quota backoff). The browser-testable surface is the Sync History LiveView at
`/integrations/sync-history`, which surfaces GA4 sync results in real time and describes
the automated sync schedule. Backend behaviors are verified by the BDD spex suite
(`mix spex` in `test/spex/509_sync_google_analytics_4_data/`).

## Tool

web (vibium MCP browser tools for the Sync History LiveView)

## Auth

Log in as `qa@example.com` using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

The base seed script provides the `qa@example.com` owner user. No GA4 integration record
is required — the Sync History page works in both empty-state and populated-state modes.

Verify seeds are present by logging in successfully. If login fails, run:

```bash
# When Phoenix server is NOT running:
mix run priv/repo/qa_seeds.exs

# When Phoenix server IS already running (Cloudflare tunnel conflict):
cd /Users/johndavenport/Documents/github/metric_flow
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

## What To Test

### Scenario 1 — Page loads with all required sections (AC: all criteria)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify the H1 heading "Sync History" is present
- Verify the subtitle "View automated sync results and status" is present
- Verify `[data-role="sync-schedule"]` section is present
- Verify `[data-role="date-range"]` section is present
- Verify `[data-role="sync-history"]` container is present
- Take a full-page screenshot: `01-sync-history-page.png`

### Scenario 2 — Schedule section describes GA4 and automated sync behavior

Maps to AC: "System fetches GA4 data using GA4 API v1", "backfill on first sync",
"retry with exponential backoff", "covers Google Analytics as marketing provider"

- Read the text of `[data-role="sync-schedule"]`
- Verify it contains "Google Analytics" (GA4 listed as a covered marketing provider)
- Verify it contains "Google Ads" and "Facebook Ads" (other marketing providers present)
- Verify it contains "QuickBooks" (financial provider present)
- Verify it contains "daily" or "Daily" (sync frequency described)
- Verify it contains "backfill" or "historical" (first sync backfill behavior described)
- Verify it contains "retried" or "retry" or "backoff" (automatic retry behavior described)
- Verify a `.badge.badge-info` labeled "Daily" is present
- Take a screenshot: `02-schedule-section.png`

### Scenario 3 — Date range section shows yesterday's date, today excluded

Maps to AC: "subsequent daily syncs fetch data for yesterday only (avoids incomplete
current-day data)"

- Read the text of `[data-role="date-range"]`
- Verify it contains yesterday's date in ISO 8601 format (today is 2026-03-17, so expect `2026-03-16`)
- Verify it contains "today excluded" or "incomplete day"
- Verify text says "yesterday" (the section description per spec: "yesterday — today excluded, incomplete day")
- Take a screenshot: `03-date-range.png`

### Scenario 4 — Empty state when no sync records exist

Maps to AC: "backfill on first sync", "sync failures surfaced in sync history"

If the QA account has no sync records:

- Verify the `[data-role="sync-history"]` container shows an empty state card with text
  "No sync history yet."
- Verify the empty state references "Initial Sync" (via text or a badge with
  `data-sync-type="initial"`)
- Verify the empty state text references backfill behavior (e.g., "backfills all available
  historical data on first sync")
- Take a screenshot: `04-empty-state.png`

### Scenario 5 — Filter tabs are present and toggle correctly

Maps to AC: "sync failures are surfaced in sync status and history" (filter by status)

- Verify three filter buttons are present: All (`[data-role="filter-all"]`), Success
  (`[data-role="filter-success"]`), Failed (`[data-role="filter-failed"]`)
- Verify the "All" button is active by default (has `btn-primary` class)
- Click `[data-role="filter-success"]` and verify it gains `btn-primary`; "All" reverts
  to `btn-ghost`
- Click `[data-role="filter-failed"]` and verify it gains `btn-primary`
- Click `[data-role="filter-all"]` to restore the default state
- Take a screenshot after clicking "Failed": `05-filter-failed-active.png`

### Scenario 6 — Unauthenticated access is redirected to login

Maps to AC: "data scoped to the client account" (implicit auth requirement)

- Delete cookies to log out: `mcp__vibium__browser_delete_cookies()`
- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify the browser lands on `/users/log-in` (not the sync history page)
- Take a screenshot: `06-unauthenticated-redirect.png`

### Scenario 7 — BDD spex suite execution

The following acceptance criteria are verified by running `mix spex` rather than through
the browser, because they test backend sync mechanics not observable in the UI:

- GA4 Data API v1 (runReport endpoint) is used, not Universal Analytics API (criterion 4746)
- Data is fetched per GA4 property selected during OAuth (criterion 4747)
- All 11 core GA4 metrics are synced as daily values (criterion 4748)
- Each metric stored as a daily time-series value keyed to property and account (criterion 4750)
- First sync backfills up to 548 days; subsequent syncs fetch from day after last stored (criterion 4751)
- Subsequent syncs fetch yesterday only to avoid incomplete current-day data (criterion 4752)
- Sampled data responses are detected and flagged (criterion 4753)
- GA4 API quota limits handled with exponential backoff and retry (criterion 4754)
- Zero-value records stored for days with no traffic (criterion 4755)
- GA4 metrics mapped to canonical names in cross-platform taxonomy (criterion 4756)
- GA4-specific metrics without canonical equivalent stored as "Google Analytics: [metric name]" (criterion 4757)
- Sync failures logged with API error response and surfaced in sync history (criterion 4758)
- Data scoped to date range dimension only, no source/medium dimensions stored (criterion 4759)
- Metrics fetched in chunks of 10 and merged by date before storage (criteria 4760, 4761)

Run with: `mix spex` (runs all specs under `test/spex/509_sync_google_analytics_4_data/`)

## Setup Notes

The Sync History LiveView handles two kinds of entries:

1. **Live events** — `{:sync_completed, payload}` and `{:sync_failed, payload}` messages
   sent to the LiveView process, prepended to `sync_events` in real time. These appear
   above persisted records in the UI.

2. **Persisted records** — loaded from the database via `DataSync.list_sync_history/1`
   on mount. These are `SyncJob` structs with `status: :success | :failed | :partial_success`.

Browser testing can observe both kinds if sync jobs exist in the QA database. However,
because QA seeds do not insert sync job records, the empty state is expected in a fresh
environment.

The BDD spex scenarios inject live sync events directly into the LiveView process using
`send(context.view.pid, {:sync_completed, payload})` — this is how they test all the
GA4-specific entry rendering (provider name, records count, data date, Initial Sync badge,
error reason, attempt counter) without needing a real GA4 API or real sync jobs.

## Result Path

`.code_my_spec/qa/509/result.md`
