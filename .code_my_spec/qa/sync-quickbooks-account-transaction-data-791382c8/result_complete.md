# QA Result

Story 518 — Sync QuickBooks Account Transaction Data

## Status

pass

## Scenarios

### Scenario 1 — Page loads and shows correct structure

pass

Navigated to `http://localhost:4070/integrations/sync-history`. The page rendered correctly with all required elements:

- H1 "Sync History" present
- Subtitle "View automated sync results and status" present
- `[data-role="sync-schedule"]` card present containing "Automated Sync Schedule" heading and "QuickBooks" in the description
- `[data-role="date-range"]` present showing "2026-03-17" (yesterday in UTC — server UTC time was already 2026-03-18)
- Three filter buttons present: `[data-role="filter-all"]`, `[data-role="filter-success"]`, `[data-role="filter-failed"]`
- "All" filter button has `btn-primary` class on initial load (confirmed via `get_attribute`)
- No `[data-role="filter-location"]` element found (confirmed with `is_visible` returning false)
- No "Transaction count" or "transaction_count" text found in page content

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_01_page_load.png`

### Scenario 2 — QuickBooks appears in the integrations connect page

pass

Navigated to `http://localhost:4070/integrations/connect`. "QuickBooks" is visible as a provider card with "Financial accounting and bookkeeping" description and a "Connected / Reconnect" status. No text "Separate QuickBooks Auth" or "secondary_auth" found anywhere on the page.

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_02_connect_page_quickbooks.png`

### Scenario 3 — Empty state when no sync history exists

pass (not applicable — sync history exists)

The QA account has prior sync records in the database so the empty state was not shown. The "No sync history yet." card and `[data-sync-type="initial"]` badge were confirmed absent (`is_visible` returned false). This is correct behavior — the empty state is conditionally rendered only when both `sync_history` and `sync_events` are empty.

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_03_empty_state.png` (shows non-empty state for reference)

### Scenario 4 — Successful QuickBooks sync entry appears in history

pass

Found two `[data-role="sync-history-entry"][data-status="success"]` entries explicitly for QuickBooks:
- "QuickBooks / Success / 7 records synced / Completed at Mar 18, 2026 03:10 UTC / Date: 2026-03-18"
- "QuickBooks / Success / 7 records synced / Completed at Mar 18, 2026 03:07 UTC / Date: 2026-03-18"

Success entries use `.badge-success` with text "Success" as expected. Provider name rendered as "QuickBooks" (not raw atom). `[data-role="sync-provider"]` element present.

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_04_sync_history_entries.png`

### Scenario 5 — Filter buttons work correctly

pass

Clicked `[data-role="filter-failed"]`:
- "Failed" button class changed to `btn btn-sm btn-primary`
- "All" button class changed to `btn btn-sm btn-ghost`
- No `[data-status="success"]` entries visible (confirmed via `find_all` returning no elements)
- Multiple `[data-status="failed"]` entries visible

Clicked `[data-role="filter-success"]`:
- "Success" button class changed to `btn btn-sm btn-primary`
- No `[data-status="failed"]` entries visible (confirmed via `find_all` returning no elements)
- Multiple `[data-status="success"]` entries visible

Clicked "All" to restore default — all entries returned.

Evidence:
- `.code_my_spec/qa/518/screenshots/screenshot_05_filter_failed.png`
- `.code_my_spec/qa/518/screenshots/screenshot_06_filter_success.png`

### Scenario 6 — Sync schedule card mentions QuickBooks

pass

`[data-role="sync-schedule"]` card contains:
- H2 "Automated Sync Schedule"
- Text "QuickBooks" in the description: "...financial providers (QuickBooks)."
- Text describing daily syncs: "Daily at 2:00 AM UTC"
- Text describing backfill: "On first sync, all available historical data is backfilled."
- `.badge-info` labeled "Daily"

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_07_schedule_card.png`

### Scenario 7 — No location filter or location column exists

pass

- `[data-role="filter-location"]` confirmed absent (`is_visible` returned false)
- Full page text inspection found no "Location" heading or "external_location_id" text in the sync history area
- All entry data-roles are limited to `sync-history-entry`, `sync-provider`, and `sync-error` — no location-related attributes present

Evidence: `.code_my_spec/qa/518/screenshots/screenshot_08_no_location_filter.png`

### Scenario 8 — Failed sync entry with error details

pass

Multiple `[data-status="failed"]` entries exist. Verified structure on the first visible failed entry (Facebook Ads):
- `[data-role="sync-provider"]` element present with text "Facebook Ads"
- `[data-role="sync-error"]` element present with error text "missing_ad_account_id"
- `.badge-error` element present with text "Failed"

Also verified Google Ads failed entries show the error text "No Google Ads customer ID configured. Go to the integration's account selection to choose an account."

Evidence:
- `.code_my_spec/qa/518/screenshots/screenshot_09_failed_entry.png`
- `.code_my_spec/qa/518/screenshots/screenshot_10_old_failed_entries.png`

## Evidence

- `.code_my_spec/qa/518/screenshots/screenshot_01_page_load.png` — Initial page load of `/integrations/sync-history`
- `.code_my_spec/qa/518/screenshots/screenshot_02_connect_page_quickbooks.png` — Connect page showing QuickBooks as a connected provider
- `.code_my_spec/qa/518/screenshots/screenshot_03_empty_state.png` — Sync history page (non-empty state — prior syncs exist)
- `.code_my_spec/qa/518/screenshots/screenshot_04_sync_history_entries.png` — QuickBooks success entries visible in history list
- `.code_my_spec/qa/518/screenshots/screenshot_05_filter_failed.png` — Failed filter active, only failed entries shown
- `.code_my_spec/qa/518/screenshots/screenshot_06_filter_success.png` — Success filter active, only success entries shown
- `.code_my_spec/qa/518/screenshots/screenshot_07_schedule_card.png` — Schedule card with QuickBooks mention
- `.code_my_spec/qa/518/screenshots/screenshot_08_no_location_filter.png` — Confirms no location filter present
- `.code_my_spec/qa/518/screenshots/screenshot_09_failed_entry.png` — Failed entry with error text and badge
- `.code_my_spec/qa/518/screenshots/screenshot_10_old_failed_entries.png` — Older failed entries showing module-prefixed error messages

## Issues

### Older failed entries expose internal Elixir module names in error messages

#### Severity
LOW

#### Scope
APP

#### Description

Some persisted failed sync entries (from 2026-03-17) display error messages that include full Elixir module paths visible to the user, for example:

- "MetricFlow.DataSync.DataProviders.FacebookAds: missing_ad_account_id"
- "MetricFlow.DataSync.DataProviders.GoogleAnalytics: No Google Analytics property configured. Go to the integration's account selection to choose a property.; MetricFlow.DataSync.DataProviders.GoogleAds: No Google Ads customer ID configured. Go to the integration's account selection to choose an account."

These appear in `[data-role="sync-error"]` elements on the sync history page for older records (those dated 2026-03-17). Newer records (2026-03-18) show cleaner messages without module prefixes (e.g. just "missing_ad_account_id" or "No Google Ads customer ID configured...").

This suggests the error message format changed between the two dates — older records were stored with the module name prepended, newer ones are stored without it. The raw module path should not be surfaced in the UI.

Reproduced at: `http://localhost:4070/integrations/sync-history` — scroll to entries dated 2026-03-17 with status "Failed".
