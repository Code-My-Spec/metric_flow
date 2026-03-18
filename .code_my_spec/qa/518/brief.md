# QA Story Brief

Story 518 — Sync QuickBooks Account Transaction Data

## Tool

web (Vibium MCP browser tools — all tested routes are LiveView pages behind `require_authenticated_user`)

## Auth

Log in using the Vibium MCP tools:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

Credentials: `qa@example.com` / `hello world!`

Note: Do NOT use `wait(selector: "body")` after login — the HTTP POST→redirect will timeout. Use `wait_for_url` instead.

## Seeds

Verify seeds are already in place by checking that login succeeds. If login fails (user not found), run:

```bash
mix run priv/repo/qa_seeds.exs
```

No story-specific seeds are needed beyond the base QA user and account. The SyncHistory page is populated by live PubSub events sent to the LiveView process — no pre-seeded sync records are required.

## What To Test

The SyncHistory LiveView at `/integrations/sync-history` is the primary surface under test. It displays real-time sync events sent to the LiveView process as `{:sync_completed, payload}` and `{:sync_failed, payload}` messages, and also renders persisted `DataSync.list_sync_history/1` records from the database.

For browser-based testing, verify the static page structure first (visible headings, filter buttons, schedule card, date range). Then verify the QuickBooks-related behavior is correctly reflected in page state.

### Scenario 1 — Page loads and shows correct structure (AC: all)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify the page renders with:
  - H1 "Sync History"
  - Subtitle "View automated sync results and status"
  - A schedule card (`data-role="sync-schedule"`) containing "Automated Sync Schedule" heading and the description mentioning "QuickBooks"
  - A date range section (`data-role="date-range"`) showing yesterday's date
  - Three filter buttons: All (`data-role="filter-all"`), Success (`data-role="filter-success"`), Failed (`data-role="filter-failed"`)
  - The "All" filter button is active (has `btn-primary` class) on initial load
- Verify there is NO `[data-role='filter-location']` element on the page (AC: platformExternalId — no location concept)
- Verify there is NO "Transaction count" or `transaction_count` text on the page (AC: daily aggregates, not individual transactions)
- Take a screenshot: `screenshot_01_page_load.png`

### Scenario 2 — QuickBooks appears in the integrations connect page (AC: OAuth token from Story 435)

- Navigate to `http://localhost:4070/integrations/connect`
- Verify "QuickBooks" is visible in the page content
- Verify there is no text "Separate QuickBooks Auth" or "secondary_auth" on the page
- Take a screenshot: `screenshot_02_connect_page_quickbooks.png`

### Scenario 3 — Empty state when no sync history exists (AC: sync history display)

- Navigate to `http://localhost:4070/integrations/sync-history`
- If both sync history and live events are empty, the page shows "No sync history yet." in a centered card
- If the empty state is shown, verify it contains:
  - "Initial Sync" badge (`data-sync-type="initial"`)
  - Explanatory text about backfill on first sync
- Take a screenshot: `screenshot_03_empty_state.png` (or skip if entries already exist)

### Scenario 4 — Successful QuickBooks sync entry appears in history (AC: credits stored, debits stored, sync history surfaced)

After navigating to the sync history page, the LiveView process can receive events. Since tests are browser-based, verify the page structure supports the expected rendering by inspecting the DOM for the relevant `data-role` attributes and checking for QuickBooks-related content in any existing persisted sync history entries.

- Navigate to `http://localhost:4070/integrations/sync-history`
- Check the page HTML for any `data-role="sync-history-entry"` elements with `data-status="success"` and QuickBooks content
- Check whether the page shows "QuickBooks" anywhere in sync entries (if prior syncs have run)
- Verify that success entries use `badge-success` with text "Success"
- Take a screenshot: `screenshot_04_sync_history_entries.png`

### Scenario 5 — Filter buttons work correctly (AC: sync failures surfaced in sync status and history)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Click the "Failed" filter button (`[data-role='filter-failed']`)
- Verify the "Failed" button becomes active (`btn-primary`)
- Verify the "All" button becomes inactive (`btn-ghost`)
- If any `data-status="failed"` entries exist: verify they remain visible; verify no `data-status="success"` entries are visible
- Click the "Success" filter button (`[data-role='filter-success']`)
- Verify the "Success" button becomes active (`btn-primary`)
- If any `data-status="success"` entries exist: verify they remain visible; verify no `data-status="failed"` entries are visible
- Click the "All" filter button to restore default
- Take a screenshot: `screenshot_05_filter_failed.png` (after clicking Failed filter)
- Take a screenshot: `screenshot_06_filter_success.png` (after clicking Success filter)

### Scenario 6 — Sync schedule card mentions QuickBooks (AC: daily sync of QuickBooks data)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify the schedule card at `data-role="sync-schedule"` contains the text "QuickBooks"
- Verify it describes daily syncs and mentions backfill on first sync
- Take a screenshot: `screenshot_07_schedule_card.png`

### Scenario 7 — No location filter or location column exists (AC: externalLocationId is null — no location concept)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Use `browser_find` or `browser_is_visible` to confirm `[data-role='filter-location']` does NOT exist
- Use `browser_get_text()` to confirm "Location" or "external_location_id" does not appear in the sync history area
- Take a screenshot: `screenshot_08_no_location_filter.png`

### Scenario 8 — Failed sync entry with error details (AC: sync failures logged with full error context)

- If any `data-status="failed"` entries exist on the sync history page:
  - Verify the entry has a `[data-role='sync-error']` element containing error text
  - Verify the entry shows provider name (`[data-role='sync-provider']`)
  - Verify the entry shows a "Failed" badge (`badge-error`)
- Take a screenshot: `screenshot_09_failed_entry.png`

## Setup Notes

This story's main user-facing surface is the SyncHistory LiveView at `/integrations/sync-history`. The core sync behaviors (backfill logic, metric key generation, daily aggregation, zero-value records) are backend/data layer concerns that are verified by unit/integration tests via `mix spex`. Browser-based QA verifies the LiveView correctly surfaces sync status, history entries, filter behavior, and error context — as a tester you are checking the UI wiring, not triggering live QuickBooks API calls.

The BDD specs test sync behavior by sending `{:sync_completed, payload}` and `{:sync_failed, payload}` messages directly to the LiveView PID. These are not reproducible via browser automation. Browser testing focuses on:

1. Page structure is correct (headings, schedule card, date range, filter buttons)
2. QuickBooks appears as a known provider (connect page, schedule description)
3. Filter buttons work (All/Success/Failed toggle and filter list correctly)
4. Existing persisted sync history entries (from prior syncs) display correctly with proper `data-role` attributes and status badges
5. No location-based UI elements exist (confirming no location concept for financial data)
6. No transaction-count UI elements exist (confirming daily aggregate model)

If the app has prior QuickBooks sync records in the database (from integration tests or previous runs), those will appear as persisted entries and can be verified for correct provider name, status badge, record count, and data date display.

## Result Path

`.code_my_spec/qa/518/result.md`
