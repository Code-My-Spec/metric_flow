# QA Result

Story 513 — Sync Google Business Profile Reviews

## Status

pass

## Scenarios

### Scenario 1 — Page loads and shows sync schedule

pass

Navigated to `http://localhost:4070/integrations/sync-history`. H1 reads "Sync History". The `[data-role="sync-schedule"]` card is present and its description explicitly mentions "Google Business Profile": "Covers marketing providers (Google Ads, Facebook Ads, Google Analytics, Google Business Profile, Google Search Console) and financial providers (QuickBooks)." The `.badge-info` "Daily" badge is present. The `[data-role="date-range"]` shows "Showing data through 2026-03-17 (yesterday — today excluded, incomplete day)" — correct (server UTC date is 2026-03-18, yesterday is 2026-03-17).

Evidence: `screenshots/01-sync-history-page-load.png`

### Scenario 2 — Provider name mapping for google_business_reviews

pass

The `@provider_names` map in `sync_history.ex` line 26 includes `google_business_reviews: "Google Business Reviews"`. The page has persisted sync history entries (Google Ads, Google Analytics, Facebook Ads) — no `google_business_reviews` entries are persisted in the QA database, so the empty-state card is not shown. The `provider_display_name/1` function correctly maps the atom to "Google Business Reviews" as verified by the spex tests.

Evidence: `screenshots/02-empty-state-or-history.png`

### Scenario 3 — Filter tabs are rendered and functional

pass

All three filter buttons are present: `[data-role="filter-all"]`, `[data-role="filter-success"]`, `[data-role="filter-failed"]`. The "All" button has class `btn btn-sm btn-primary` by default. Clicking "Success" gives it `btn-primary`. Clicking "Failed" gives it `btn-primary`. Clicking "All" restores `btn-primary` to "All". Filter transitions are functional.

Evidence: `screenshots/03-filter-tabs.png`

### Scenario 4 — Unauthenticated access is redirected

pass

`curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history` returned `302`. The auth guard is working correctly.

### Scenario 5 — Persisted sync history entries render correctly

pass

Multiple `[data-role="sync-history-entry"]` elements are present. Each entry shows a `[data-role="sync-provider"]` span with the display name (e.g., "Google Ads", "Google Analytics", "Facebook Ads"), a status badge (`.badge-success` "Success" or `.badge-error` "Failed"), and for success entries a "records synced" count (e.g., "186 records synced"). No `google_business_reviews` persisted entry exists in the QA database — the provider name mapping is verified via spex.

Evidence: `screenshots/05-persisted-entries.png`

### Scenario 6 — Failed filter shows only failed entries

pass

Clicking the "Failed" filter tab hides all `[data-status="success"]` entries (confirmed with `browser_is_visible` returning `false`) and shows only `[data-status="failed"]` entries (confirmed with `browser_is_visible` returning `true`). Clicking "All" restores all entries.

Evidence: `screenshots/06-failed-filter.png`

### Scenario 7 — mix spex suite for Story 513

pass

All 11 spex tests pass. The previously failing criterion_4797 test has been fixed — it now uses `has_element?(context.view, "[data-status='failed']")` and `refute has_element?(context.view, "[data-status='success']")` instead of the overly broad `html =~ "Success"` string match. All criteria 4787–4797 pass.

```
criterion_4787: 1 test, 0 failures
criterion_4788: 1 test, 0 failures
criterion_4789: 1 test, 0 failures
criterion_4790: 1 test, 0 failures
criterion_4791: 1 test, 0 failures
criterion_4792: 1 test, 0 failures
criterion_4793: 1 test, 0 failures
criterion_4794: 1 test, 0 failures
criterion_4795: 1 test, 0 failures
criterion_4796: 1 test, 0 failures
criterion_4797: 1 test, 0 failures
```

## Evidence

- `screenshots/01-sync-history-page-load.png` — full page load, H1, schedule card, date range
- `screenshots/02-empty-state-or-history.png` — persisted history entries visible, no google_business_reviews entry
- `screenshots/03-filter-tabs.png` — filter tabs rendered with "All" active
- `screenshots/05-persisted-entries.png` — persisted entry cards with provider names, status badges, records synced
- `screenshots/06-failed-filter.png` — "Failed" filter active, success entries hidden

## Issues

None
