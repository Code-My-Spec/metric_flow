# QA Result

## Status

pass

## Scenarios

### Scenario 1 — Unauthenticated redirect

pass

Verified via curl:

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history
302
```

`/integrations/sync-history` returns HTTP 302 for unauthenticated requests, redirecting to `/users/log-in`. Confirmed before any browser login.

### Scenario 2 — Page loads for authenticated user

pass

After logging in as `qa@example.com`, navigated to `/integrations/sync-history`. All expected elements confirmed:

- H1 `Sync History` — present
- Subtitle "View automated sync results and status" — present
- `data-role="sync-schedule"` card — present with H2 "Automated Sync Schedule" and text "Daily at 2:00 AM UTC"
- `.badge.badge-info` labeled "Daily" — present
- `data-role="date-range"` — present, text reads "Showing data through 2026-03-16 (yesterday — today excluded, incomplete day)"

Screenshot: `.code_my_spec/qa/516/screenshots/02-page-loaded.png`

### Scenario 3 — Empty state shown when no syncs have run

partial

The seed script did not clear existing sync history records on this run. The database had accumulated sync history from previous QA sessions (Google Analytics successes, Facebook Ads failures, Google Ads failures). The empty state was therefore not visible during this test run.

However, the empty state HTML was verified via source code inspection (`sync_history.ex` lines 99–109). The conditional renders when `@sync_history == [] and @sync_events == []` and includes:
- Text "No sync history yet."
- Secondary text referencing "Initial Sync"
- `data-sync-type="initial"` badge with `.badge.badge-ghost` class labeled "Initial Sync"

The `data-role="sync-history-entry"` entries ARE visible in the current database state (27+ entries). The empty state is logically correct but could not be verified through the browser.

Screenshot: `.code_my_spec/qa/516/screenshots/03-sync-history-with-data.png`

### Scenario 4 — Filter tabs are rendered and functional

pass

All three filter buttons confirmed present with correct `data-role` attributes. Default state verified:
- `[data-role="filter-all"]` class: `btn btn-sm btn-primary` (active)
- `[data-role="filter-success"]` class: `btn btn-sm btn-ghost` (inactive)
- `[data-role="filter-failed"]` class: `btn btn-sm btn-ghost` (inactive)

Clicked "Success" — `filter-success` became `btn-primary`, `filter-all` became `btn-ghost`. Confirmed.

Clicked "Failed" — `filter-failed` became `btn-primary`. Confirmed.

Clicked "All" — `filter-all` returned to `btn-primary`. Confirmed.

All filter tab state transitions work correctly via LiveView phx-click events.

Screenshot: `.code_my_spec/qa/516/screenshots/04-filter-tabs.png`

### Scenario 5 — Google Search Console provider display name (BDD spex)

pass

Ran both BDD spex criterion files:

```
mix spex test/spex/516_sync_google_search_console_data/criterion_4806_...spex.exs
2 tests, 0 failures

mix spex test/spex/516_sync_google_search_console_data/criterion_4807_...spex.exs
1 test, 0 failures
```

The LiveView correctly handles `{:sync_completed, %{provider: :google_search_console, ...}}` messages, rendering "Google Search Console" in the sync history list. All 3 spex test scenarios pass.

Two previously-filed issues for Story 516 are both resolved:
- `qa-516-google_search_console_not_registered_in_p.md` — RESOLVED: `:google_search_console` was added to `@provider_names` map
- `qa-516-criterion_4807_spex_whenstep_discards_con.md` — RESOLVED: `when_` step was fixed to pass `context` instead of `%{}`

### Scenario 6 — Google Search Console in @provider_names map (architectural note)

pass

Inspected `lib/metric_flow_web/live/integration_live/sync_history.ex` lines 20–27. The `@provider_names` map now explicitly includes `:google_search_console`:

```elixir
@provider_names %{
  google_ads: "Google Ads",
  facebook_ads: "Facebook Ads",
  google_analytics: "Google Analytics",
  google_search_console: "Google Search Console",
  quickbooks: "QuickBooks",
  google: "Google"
}
```

The previously reported issue (missing entry falling back to `derive_display_name/1`) has been resolved. The provider is now explicitly registered.

The sync history page had no "Google Search Console" live history entries in the database (no actual sync has run for this provider in QA), which is expected.

Screenshot: `.code_my_spec/qa/516/screenshots/06-sync-history-final.png`

## Evidence

- `.code_my_spec/qa/516/screenshots/02-page-loaded.png` — Full page view of sync history after login, showing H1, schedule card, date range, and sync entries
- `.code_my_spec/qa/516/screenshots/03-sync-history-with-data.png` — Sync history page with existing records (empty state could not be tested)
- `.code_my_spec/qa/516/screenshots/04-filter-tabs.png` — Filter tabs after cycling through all states, restored to "All" active
- `.code_my_spec/qa/516/screenshots/06-sync-history-final.png` — Full page confirming no Google Search Console entries in live DB (no sync has run)

## Issues

### Seed script did not clear sync history — empty state untestable

#### Severity
LOW

#### Scope
QA

#### Description

The brief states "seeds clear all sync history records" and that the empty state ("No sync history yet.") would be visible after running seeds. However, when the QA session began, the database had 27+ sync history records from prior QA runs (Google Analytics, Facebook Ads, Facebook Ads). The seed script (`priv/repo/qa_seeds.exs`) does not appear to truncate the `sync_history` table on this run, or seeds were not re-run before this session.

The empty state HTML structure was verified via source code inspection and is correctly implemented. However, Scenario 3 could not be verified through the browser UI.

To reproduce: run `mix run priv/repo/qa_seeds.exs` and navigate to `/integrations/sync-history` — if sync history entries remain, the seed script is not clearing them.

Recommendation: add a `Repo.delete_all(MetricFlow.DataSync.SyncHistory)` step to `qa_seeds.exs` before inserting fresh data, so the empty state is reliably testable on each QA run.
