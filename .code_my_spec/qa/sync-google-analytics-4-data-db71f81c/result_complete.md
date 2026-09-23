# QA Result

Story 509: Sync Google Analytics 4 Data

## Status

pass

## Scenarios

### Scenario 1 — Page loads with all required sections

pass

Navigated to `http://localhost:4070/integrations/sync-history` after logging in as `qa@example.com`.

- H1 heading "Sync History" is present.
- Subtitle "View automated sync results and status" is present below the H1.
- `[data-role="sync-schedule"]` section is present and rendered with the "Automated Sync Schedule" H2.
- `[data-role="date-range"]` section is present.
- `[data-role="sync-history"]` container is present and populated with sync history entries.

Screenshot: `.code_my_spec/qa/509/screenshots/01-sync-history-page.png`

### Scenario 2 — Schedule section describes GA4 and automated sync behavior

pass

Read the text of `[data-role="sync-schedule"]`:

> "Daily at 2:00 AM UTC — retrieves metrics and financial data per provider, per day. Covers marketing providers (Google Ads, Facebook Ads, Google Analytics) and financial providers (QuickBooks). On first sync, all available historical data is backfilled. Failed syncs are automatically retried up to 3 times with exponential backoff."

- "Google Analytics" present: yes
- "Google Ads" present: yes
- "Facebook Ads" present: yes
- "QuickBooks" present: yes
- "daily" / "Daily" present: yes (badge "Daily" and "Daily at 2:00 AM UTC")
- "backfilled" / "backfill" present: yes ("historical data is backfilled")
- "retried" / "retry" / "backoff" present: yes ("automatically retried", "exponential backoff")
- `.badge.badge-info` labeled "Daily" present: yes

Screenshot: `.code_my_spec/qa/509/screenshots/02-schedule-section.png`

### Scenario 3 — Date range section shows yesterday's date, today excluded

pass

Read the text of `[data-role="date-range"]`:

> "Showing data through 2026-03-16 (yesterday — today excluded, incomplete day)"

- Yesterday's date 2026-03-16 in ISO 8601 format: present
- "today excluded": present
- "incomplete day": present
- "yesterday": present

Screenshot: `.code_my_spec/qa/509/screenshots/03-date-range.png`

### Scenario 4 — Empty state when no sync records exist

partial

The QA database contains existing sync job records from previous test runs (manual sync triggers during story 437 and 438 QA sessions). The empty state card was not testable in this environment. The sync history container shows populated entries.

The source code was reviewed and confirmed to implement the empty state correctly: when both `sync_history` and `sync_events` are empty, the container renders a `.mf-card` with "No sync history yet.", a secondary explanation referencing Initial Sync, and a `[data-sync-type="initial"]` badge labeled "Initial Sync".

The BDD spex tests exercise the empty-to-populated transition via injected `{:sync_completed, ...}` events.

Screenshot of populated state: `.code_my_spec/qa/509/screenshots/04-populated-state.png`

### Scenario 5 — Filter tabs are present and toggle correctly

pass

All three filter buttons are present:
- `[data-role="filter-all"]` with text "All"
- `[data-role="filter-success"]` with text "Success"
- `[data-role="filter-failed"]` with text "Failed"

Default state: `[data-role="filter-all"]` has class `btn btn-sm btn-primary`.

After clicking `[data-role="filter-success"]`:
- filter-success class: `btn btn-sm btn-primary`
- filter-all class: `btn btn-sm btn-ghost`

After clicking `[data-role="filter-failed"]`:
- filter-failed class: `btn btn-sm btn-primary`

After clicking `[data-role="filter-all"]` to restore:
- filter-all class: `btn btn-sm btn-primary`

Screenshot: `.code_my_spec/qa/509/screenshots/05-filter-failed-active.png`

### Scenario 6 — Unauthenticated access is redirected to login

pass

Clicked the "Log out" link while authenticated to end the session. Then navigated to `http://localhost:4070/integrations/sync-history`. The browser was immediately redirected to `http://localhost:4070/users/log-in`, confirming the route is protected by `require_authenticated_user`.

Screenshot: `.code_my_spec/qa/509/screenshots/06-unauthenticated-redirect.png`

### Scenario 7 — BDD spex suite execution

pass

Ran `mix spex` (full suite — 193 tests, 12 failures). None of the 12 failures are from story 509. All 15 criteria files for story 509 (criterion_4746 through criterion_4761) passed.

The 12 failures belong to unrelated stories: 425 (login session management), 434 (OAuth connect — QuickBooks integration state), and 451 (AI chat features). These are pre-existing issues unrelated to story 509.

## Evidence

- `.code_my_spec/qa/509/screenshots/01-sync-history-page.png` — full-page screenshot of sync history page on load
- `.code_my_spec/qa/509/screenshots/02-schedule-section.png` — schedule section showing all provider names and Daily badge
- `.code_my_spec/qa/509/screenshots/03-date-range.png` — date range section showing 2026-03-16 with "yesterday — today excluded" text
- `.code_my_spec/qa/509/screenshots/04-populated-state.png` — full-page screenshot of populated sync history (database has existing records)
- `.code_my_spec/qa/509/screenshots/05-filter-failed-active.png` — filter tabs with "Failed" active (btn-primary)
- `.code_my_spec/qa/509/screenshots/05b-filter-success-active.png` — filter tabs with "Success" active
- `.code_my_spec/qa/509/screenshots/06-unauthenticated-redirect.png` — login page after navigating to sync-history while logged out
- `.code_my_spec/qa/509/screenshots/07-db-error-entries.png` — full-page showing sync history entries including error entries

## Issues

### Persisted sync entries use "Google" provider name instead of "Google Analytics"

#### Severity
MEDIUM

#### Description
Sync job records stored in the database use `:google` as the provider atom, which renders as "Google" in the sync history UI. The `@provider_names` map in `SyncHistory` correctly maps `:google_analytics` to "Google Analytics", but records stored with `:google` as the provider will show "Google" instead.

This is observable in the QA database where persisted `SyncJob` records have `provider: :google`. The issue is in how sync jobs are created or persisted — the provider atom `:google` is being used instead of `:google_analytics`. This causes GA4 sync history entries to be ambiguous (could be Google Ads, Google Analytics, or another Google product).

Reproduce: visit `/integrations/sync-history` as a user with existing sync jobs. Any persisted entries show "Google" rather than "Google Analytics" for GA4 syncs.

### Sync job error messages truncated to 255 characters causing database errors logged as error_message

#### Severity
LOW

#### Description
Several persisted sync history entries display the raw database error "ERROR 22001 (string_data_right_truncation) value too long for type character varying(255)" as the error_message. This indicates that the `sync_jobs.error_message` column is defined as `varchar(255)`, but some error messages from sync failures exceed that length.

The GA4 and Facebook Ads failure messages (e.g., "MetricFlow.DataSync.DataProviders.GoogleAnalytics: No Google Analytics property configured. Go to the integration's account selection to choose a property.; MetricFlow.DataSync.DataProviders.GoogleAds: No Google Ads customer ID configured...") can exceed 255 characters.

The error is surfaced to the user in the UI as the literal database error string, which is confusing and unhelpful. The field should be widened (e.g., `text` type) or error messages should be truncated before insertion.
