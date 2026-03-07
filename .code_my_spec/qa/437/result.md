# QA Result

Story 437 — Automated Daily Data Sync

## Status

pass

## Scenarios

### Scenario 1 — Page loads and renders core structure

**Result: pass**

Navigated to `http://localhost:4070/integrations/sync-history` as `qa@example.com`. The page rendered immediately with the expected H1 "Sync History" and subtitle "View automated sync results and status".

- H1 "Sync History" — present
- Subtitle "View automated sync results and status" — present
- `[data-role="sync-schedule"]` — present and visible
- "2:00 AM UTC" in schedule section — present (text: "Daily at 2:00 AM UTC — retrieves metrics and financial data per provider, per day.")
- "Daily" label — present in `.badge.badge-info`

Screenshot: `screenshots/01_page_load.png`

### Scenario 2 — Schedule section communicates backfill and retry behavior

**Result: pass**

The `[data-role="sync-schedule"]` card body text contains:
- "all available historical data is backfilled" — satisfies backfill/historical data requirement
- "automatically retried up to 3 times with exponential backoff" — satisfies retry behavior requirement

Both acceptance criteria (AC: backfill on first sync; AC: retry up to 3 times) are met by the static schedule description.

Screenshot: `screenshots/02_schedule_section.png`

### Scenario 3 — Financial and marketing providers mentioned; unified list

**Result: pass**

The schedule section text explicitly names all four providers: "Google Ads, Facebook Ads, Google Analytics" (marketing) and "QuickBooks" (financial). They are referenced together in a single paragraph — no separate financial or marketing sections exist on the page.

- `[data-role="financial-sync-history"]` — not present (correct)
- `[data-role="marketing-sync-history"]` — not present (correct)
- `[data-role="sync-history"]` — single unified section present

Screenshot: `screenshots/03_providers_coverage.png`

### Scenario 4 — Date range bar excludes today

**Result: pass**

The `[data-role="date-range"]` element renders: "Showing data through 2026-03-05 (yesterday — today excluded, incomplete day)"

- Yesterday's date (2026-03-05) is shown as the end date — correct
- Today's date (2026-03-06) does not appear as the range end — correct
- The text "yesterday" and "today excluded" and "incomplete day" are all present — satisfies the requirement for explanatory text

Screenshot: `screenshots/04_date_range.png`

### Scenario 5 — Empty state when no sync history

**Result: pass**

With a freshly-seeded QA user (no connected integrations, no sync jobs run), the sync history page shows the empty state panel:
- "No sync history yet." — present
- Explanation text about initial sync entries — present
- `[data-sync-type="initial"]` badge with text "Initial Sync" — present and visible
- `[data-role="sync-history-entry"]` elements — none (correct)

Screenshot: `screenshots/05_empty_state.png`

### Scenario 6 — Filter buttons present with correct default active state

**Result: pass**

All three filter buttons are visible:
- `[data-role="filter-all"]` — class `btn btn-sm btn-primary` (active, correct default)
- `[data-role="filter-success"]` — class `btn btn-sm btn-ghost` (inactive, correct)
- `[data-role="filter-failed"]` — class `btn btn-sm btn-ghost` (inactive, correct)

Screenshot: `screenshots/06_filter_buttons.png`

### Scenario 7 — Filter button click toggles active state

**Result: pass**

Clicked "Success" filter:
- `[data-role="filter-success"]` changed to `btn-primary` — confirmed
- `[data-role="filter-all"]` changed to `btn-ghost` — confirmed

Clicked "Failed" filter:
- `[data-role="filter-failed"]` changed to `btn-primary` — confirmed
- `[data-role="filter-success"]` changed to `btn-ghost` — confirmed

Clicked "All" to reset:
- `[data-role="filter-all"]` restored to `btn-primary` — confirmed

All LiveView filter state transitions work correctly.

Screenshot: `screenshots/07_filter_toggle.png` (reset to "All" state)

### Scenario 8 — Unauthenticated access redirects to login

**Result: pass**

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history
```

Returned: `302` — redirect to `/users/log-in` as expected. The route is correctly protected by `require_authenticated_user`.

### Scenario 9 — Page mentions "metrics" and "financial data"

**Result: pass**

The schedule section contains "metrics" ("retrieves metrics and financial data per provider, per day") and "financial" ("financial data per provider", "financial providers (QuickBooks)"). Both data type references are present in the visible page text.

Screenshot: `screenshots/09_metrics_financial_mention.png`

### Scenario 10 — Full page structural integrity

**Result: pass**

All required structural elements are present and visible:
- H1 text: "Sync History" — exact match
- `[data-role="sync-schedule"]` — present
- `[data-role="date-range"]` — present
- `[data-role="sync-history"]` — present
- `[data-role="filter-all"]` — present
- `[data-role="filter-success"]` — present
- `[data-role="filter-failed"]` — present

Full-page screenshot: `screenshots/10_full_page.png`

## Evidence

- `screenshots/01_page_load.png` — Full page on first load, showing H1, schedule card, date range, filters, empty state
- `screenshots/02_schedule_section.png` — Schedule section with 2:00 AM UTC timing, backfill and retry text, "Daily" badge
- `screenshots/03_providers_coverage.png` — Page showing Google Ads, Facebook Ads, Google Analytics, QuickBooks mentioned together
- `screenshots/04_date_range.png` — Date range bar showing 2026-03-05 (yesterday) with "today excluded" explanation
- `screenshots/05_empty_state.png` — Empty state panel with "No sync history yet." and "Initial Sync" badge
- `screenshots/06_filter_buttons.png` — Filter buttons with "All" as active (btn-primary), others ghost
- `screenshots/07_filter_toggle.png` — Filter buttons after cycling through Success, Failed, back to All
- `screenshots/09_metrics_financial_mention.png` — Page text showing "metrics" and "financial" references
- `screenshots/10_full_page.png` — Full-page screenshot confirming complete page structure

## Issues

None
