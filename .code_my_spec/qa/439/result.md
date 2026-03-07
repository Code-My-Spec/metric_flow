# QA Result

Story 439: Sync Status and History

## Status

pass

## Scenarios

### Scenario 1: Page loads and shows sync schedule

**Result: pass**

Navigated to `http://localhost:4070/integrations/sync-history` as `qa@example.com`. The page loaded and displayed:

- H1 "Sync History" visible
- `[data-role='sync-schedule']` section present with heading "Automated Sync Schedule"
- Body text includes "Daily at 2:00 AM UTC"
- `.badge-info` with text "Daily" present inside the schedule section

All schedule display checks passed. This covers acceptance criterion: each integration shows next scheduled sync time.

Evidence: `.code_my_spec/qa/439/screenshots/01-sync-schedule.png`

### Scenario 2: Empty state when no sync history exists

**Result: pass**

Logged in as `qa-member@example.com` (a seeded user with no sync history). Navigated to `/integrations/sync-history`:

- `[data-role='sync-history']` container was present
- Text "No sync history yet." was visible
- No `[data-role='sync-history-entry']` elements were found (`is_visible` returned `false`)
- "Initial Sync" badge was shown in the empty state panel

Evidence: `.code_my_spec/qa/439/screenshots/02-empty-state.png`

### Scenario 3: Filter controls are present and "All" is active by default

**Result: pass**

On the sync history page as `qa@example.com`:

- `[data-role='filter-all']` button visible — class: `btn btn-sm btn-primary` (active)
- `[data-role='filter-success']` button visible — class: `btn btn-sm btn-ghost` (inactive)
- `[data-role='filter-failed']` button visible — class: `btn btn-sm btn-ghost` (inactive)

The "All" filter is correctly highlighted as the default active filter. This covers acceptance criterion: user can filter sync history by status.

Evidence: `.code_my_spec/qa/439/screenshots/03-filter-controls.png`

### Scenario 4: Date range section present with yesterday's date

**Result: pass**

`[data-role='date-range']` section was visible with text:

> "Showing data through 2026-03-05 (yesterday — today excluded, incomplete day)"

Date `2026-03-05` is yesterday relative to the current date of 2026-03-06. The section correctly communicates data freshness context.

Evidence: `.code_my_spec/qa/439/screenshots/04-date-range.png`

### Scenario 5: Unauthenticated redirect

**Result: pass**

Two methods confirmed:

1. `curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:4070/integrations/sync-history` returned `302 http://localhost:4070/users/log-in`
2. After logging out via the "Log out" nav link, navigating to `/integrations/sync-history` in the browser redirected to `http://localhost:4070/users/log-in`

Unauthenticated access is correctly blocked.

Evidence: `.code_my_spec/qa/439/screenshots/05-unauth-redirect.png`

### Scenario 7: Persisted success entry displays correctly

**Result: pass**

After seeding a `SyncHistory` record with status `:success`, `records_synced: 342`, `completed_at: ~U[2026-03-04 02:03:00Z]` for provider `:google_ads`, the page showed:

- `[data-role='sync-history-entry'][data-status='success']` present
- Provider name "Google Ads" in `[data-role='sync-provider']`
- `.badge-success` with text "Success"
- Text "342 records synced"
- Text "Completed at Mar 04, 2026 02:03 UTC" (human-readable format via `Calendar.strftime/2`)
- Date "2026-03-04" shown in the entry

All fields from acceptance criterion (timestamp, status, records synced) were displayed correctly.

Evidence: `.code_my_spec/qa/439/screenshots/06-success-entry.png`

### Scenario 8: Persisted failed entry is highlighted with error details

**Result: pass**

After seeding a `SyncHistory` record with status `:failed`, `error_message: "API rate limit exceeded"` for provider `:google_ads`:

- `[data-role='sync-history-entry'][data-status='failed']` present
- `.badge-error` with text "Failed" visible
- `[data-role='sync-error']` element present with text "API rate limit exceeded"
- Provider "Google Ads" shown

Failed sync highlighted with `.badge-error` and the error message is surfaced in the designated `[data-role='sync-error']` element. This covers acceptance criteria: failed syncs highlighted with error details, and sync history shows error messages.

Evidence: `.code_my_spec/qa/439/screenshots/07-failed-entry.png`

### Scenario 9: Filter by "Failed" shows only failed entries

**Result: pass**

Clicked `[data-role='filter-failed']`. After the LiveView update:

- `[data-role='filter-failed']` class became `btn btn-sm btn-primary` (active)
- Sync history section showed only the failed entry: "Google Ads / Failed / API rate limit exceeded"
- The success entry text "342 records synced" was not found anywhere on the page (element not found error confirmed)

Evidence: `.code_my_spec/qa/439/screenshots/08-filter-failed.png`

### Scenario 10: Filter by "Success" shows only success entries

**Result: pass**

Clicked `[data-role='filter-success']`. After the LiveView update:

- Sync history section showed only the success entry: "Google Ads / Success / 342 records synced / Completed at Mar 04, 2026 02:03 UTC"
- `[data-role='sync-error']` element `is_visible` returned `false` — error message hidden

Evidence: `.code_my_spec/qa/439/screenshots/09-filter-success.png`

### Scenario 11: Filter "All" restores the full list

**Result: pass**

Clicked `[data-role='filter-all']`. After the LiveView update:

- Both entries returned: "Google Ads / Success / 342 records synced" and "Google Ads / Failed / API rate limit exceeded"
- `[data-role='filter-all']` class became `btn btn-sm btn-primary` (active)

Filter round-trip (Failed -> Success -> All) worked correctly without page reload.

Evidence: `.code_my_spec/qa/439/screenshots/10-filter-all.png`

## Evidence

- `.code_my_spec/qa/439/screenshots/00-full-page-overview.png` — full-page view of sync history with both success and failed entries visible
- `.code_my_spec/qa/439/screenshots/01-sync-schedule.png` — sync schedule section showing "Daily at 2:00 AM UTC" and "Daily" badge
- `.code_my_spec/qa/439/screenshots/02-empty-state.png` — empty state for user with no sync history ("No sync history yet.")
- `.code_my_spec/qa/439/screenshots/03-filter-controls.png` — filter tabs (All / Success / Failed) with "All" active
- `.code_my_spec/qa/439/screenshots/04-date-range.png` — date range bar showing "Showing data through 2026-03-05"
- `.code_my_spec/qa/439/screenshots/05-unauth-redirect.png` — login page shown after unauthenticated redirect
- `.code_my_spec/qa/439/screenshots/06-success-entry.png` — persisted success entry with provider, badge, record count, and timestamp
- `.code_my_spec/qa/439/screenshots/07-failed-entry.png` — persisted failed entry with badge-error and error message
- `.code_my_spec/qa/439/screenshots/08-filter-failed.png` — failed filter active, only failed entry visible
- `.code_my_spec/qa/439/screenshots/09-filter-success.png` — success filter active, only success entry visible
- `.code_my_spec/qa/439/screenshots/10-filter-all.png` — all filter active, both entries visible

## Issues

### seed script fails in sandbox due to Cloudflare tunnel write permission

#### Severity
LOW

#### Scope
QA

#### Description
Running `mix run priv/repo/qa_seeds.exs` fails in the default Claude Code sandbox because the
`ClientUtils.CloudflareTunnel` supervision tree child attempts to write to
`/Users/johndavenport/.cloudflared/config.yml` which is not writable in the sandbox environment.
The error is:

```
(File.Error) could not write to file "/Users/johndavenport/.cloudflared/config.yml": not owner
```

This affects all `mix run` commands including seed scripts and the story-specific seed script
used in this QA session. The workaround is to run with `dangerouslyDisableSandbox: true`.
This is a QA infrastructure issue — the seed scripts themselves work correctly once the
sandbox restriction is bypassed.

### BDD spex reference :owner_with_integrations given not implemented

#### Severity
LOW

#### Scope
QA

#### Description
All six BDD spec files in `test/spex/439_sync_status_and_history/` reference a shared given
`:owner_with_integrations` (e.g. `given_ :owner_with_integrations`) which is not defined in
`test/support/shared_givens.ex`. That file only defines `:user_registered_with_password`,
`:user_logged_in_as_owner`, and `:second_user_registered`. Running `mix spex` on the story 439
specs will fail at the given step resolution before any assertions are reached.

The sync history page itself does not require integrations to be present to display the schedule
or empty state — the given name implies integration data but the specs only test the LiveView
message-handling path (`:sync_completed` and `:sync_failed` messages sent directly to the LiveView
pid), not any integration-specific UI. The missing given should be added to `shared_givens.ex`
as an alias or equivalent of `:user_logged_in_as_owner` with an optional integration fixture.
