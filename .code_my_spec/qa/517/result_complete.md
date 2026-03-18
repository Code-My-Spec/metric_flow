# QA Result

Story 517: Sync Google Business Profile Performance Metrics

## Status

pass

## Scenarios

### Scenario 1: Unauthenticated redirect

pass

Verified via curl that `GET /integrations/sync-history` without a session returns HTTP 302. The server redirected the unauthenticated request as expected.

### Scenario 2: Sync history page loads for authenticated user

pass

Navigated to `http://localhost:4070/integrations/sync-history` while logged in as `qa@example.com`. The page rendered with:
- H1 "Sync History"
- Subtitle "View automated sync results and status"

Evidence: `.code_my_spec/qa/517/screenshots/01-sync-history-page.png`

### Scenario 3: Schedule section content and provider coverage

pass

The `[data-role="sync-schedule"]` section contains:
- H2 "Automated Sync Schedule"
- Description paragraph that mentions "Google Ads", "Facebook Ads", "Google Analytics", "Google Business Profile", "Google Search Console", and "QuickBooks"
- Daily badge

Notably, the schedule description DOES mention "Google Business Profile" — the implementation has been updated and includes Google Business Profile in the schedule text. No gap found here.

Evidence: `.code_my_spec/qa/517/screenshots/02-schedule-section.png`

### Scenario 4: Date range section

pass

The `[data-role="date-range"]` section shows: "Showing data through 2026-03-16 (yesterday — today excluded, incomplete day)". With today being 2026-03-17, yesterday is 2026-03-16, which is correct.

Evidence: `.code_my_spec/qa/517/screenshots/03-date-range.png`

### Scenario 5: Filter tabs present with correct data-role attributes

pass

All three filter tab buttons are present with correct `data-role` attributes:
- `[data-role="filter-all"]` with text "All" — initially has class `btn-primary` (active)
- `[data-role="filter-success"]` with text "Success" — initially has class `btn-ghost`
- `[data-role="filter-failed"]` with text "Failed" — initially has class `btn-ghost`

Filter cycling tested:
- Clicked "Success" — became `btn-primary`, "All" reverted to `btn-ghost` ✓
- Clicked "Failed" — became `btn-primary` ✓
- Clicked "All" — returned to `btn-primary` ✓

Evidence:
- `.code_my_spec/qa/517/screenshots/04-filter-tabs-all-active.png` (initial state)
- `.code_my_spec/qa/517/screenshots/05-filter-success-active.png` (success active)
- `.code_my_spec/qa/517/screenshots/06-filter-failed-active.png` (failed active)
- `.code_my_spec/qa/517/screenshots/07-filter-all-restored.png` (all restored)

### Scenario 6: Empty state when no sync history exists

partial

The seeded QA account has existing sync history entries (Google Analytics successes, Facebook Ads failures, and one Google Ads failure), so the empty state was not shown in the browser. The empty state code was confirmed in source: `[data-role="sync-history"]` renders a card with "No sync history yet." and an `[data-sync-type="initial"]` badge labeled "Initial Sync" when both `sync_history` and `sync_events` are empty. This behavior was validated via BDD spex tests.

Evidence: `.code_my_spec/qa/517/screenshots/08-sync-history-with-data.png` (account has history, empty state not visible)

### Scenario 7: google_business provider display name gap

pass (no gap found)

Inspected `lib/metric_flow_web/live/integration_live/sync_history.ex`. The `@provider_names` map at lines 20-29 DOES include both `:google_business => "Google Business Profile"` and `:google_business_reviews => "Google Business Reviews"`. The brief's anticipated gap has been resolved in the implementation — these providers are now in the `@provider_names` map and will display their proper human-readable names rather than falling through to `derive_display_name/1`.

### Scenario 8: Run mix spex for full BDD coverage

pass

Ran all 11 BDD spec files:

```
mix spex test/spex/517_sync_google_business_profile_performance_metrics/*.exs
```

Result: **11 tests, 0 failures** (completed in 7.1 seconds)

Criteria covered:
- 4817: Google Business Profile sync entry renders "Google Business" provider name with Success badge
- 4818: Data fetched per location ID (sync entry structure validated)
- 4819: 10 metrics fetched as daily time series (records count verified in sync events)
- 4820: Metrics stored at location level with `google_business` provider type
- 4821: Initial Sync badge appears for `sync_type: :initial` entries; empty state shown when no history
- 4822: Two consecutive sync entries appear without overlap
- 4823: Null/missing metric values produce success entries with 0 records synced
- 4824: Location details fetched for metric label generation
- 4825: Insert (not upsert) behavior — known limitation documented
- 4826: Per-customer failures caught and logged without halting other customers
- 4827: `google_business` and `google_business_reviews` are distinct providers, each with separate sync entries

## Evidence

- `.code_my_spec/qa/517/screenshots/01-sync-history-page.png` — Full page after load for authenticated user
- `.code_my_spec/qa/517/screenshots/02-schedule-section.png` — Schedule section showing Google Business Profile mention
- `.code_my_spec/qa/517/screenshots/03-date-range.png` — Date range showing yesterday (2026-03-16)
- `.code_my_spec/qa/517/screenshots/04-filter-tabs-all-active.png` — Filter tabs with "All" active
- `.code_my_spec/qa/517/screenshots/05-filter-success-active.png` — Filter tabs with "Success" active
- `.code_my_spec/qa/517/screenshots/06-filter-failed-active.png` — Filter tabs with "Failed" active
- `.code_my_spec/qa/517/screenshots/07-filter-all-restored.png` — Filter tabs restored to "All" active
- `.code_my_spec/qa/517/screenshots/08-sync-history-with-data.png` — Sync history list with real entries (no empty state)
- `.code_my_spec/qa/517/screenshots/09-provider-names-verified.png` — Page view confirming page state after all scenarios

## Issues

None
