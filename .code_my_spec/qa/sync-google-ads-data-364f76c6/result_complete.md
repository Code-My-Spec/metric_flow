# QA Result

Story 510: Sync Google Ads Data

## Status

pass

## Scenarios

### Scenario 1 — Unauthenticated redirect

pass

Visiting `http://localhost:4070/integrations/sync-history` without a session returned HTTP 302, verified via `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history`. The browser also confirmed the redirect route does not expose the page to unauthenticated users.

### Scenario 2 — Page loads for authenticated user

pass

After logging in as `qa@example.com`, navigating to `/integrations/sync-history` rendered the H1 "Sync History" and subtitle "View automated sync results and status". The page loaded successfully with existing sync entries visible.

### Scenario 3 — Sync schedule section

pass

The `[data-role='sync-schedule']` card was present and contained:
- H2: "Automated Sync Schedule"
- Text: "Daily at 2:00 AM UTC"
- Text: "Google Ads" listed among covered marketing providers
- Text: "backfilled" (confirms first-sync backfill behavior is described)
- Text: "3 times" and "exponential backoff" (confirms retry behavior is described)
- Badge `<span class="badge badge-info">Daily</span>` with `badge-info` class confirmed via HTML inspection

### Scenario 4 — Date range section

pass

The `[data-role='date-range']` element was present and showed: "Showing data through 2026-03-17 (yesterday — today excluded, incomplete day)". The date was in ISO 8601 format (YYYY-MM-DD) and included the expected parenthetical explanation.

### Scenario 5 — Filter tabs present

pass

All three filter tabs were rendered with correct classes:
- `[data-role='filter-all']`: class `btn btn-sm btn-primary` (default active state), labeled "All"
- `[data-role='filter-success']`: class `btn btn-sm btn-ghost`, labeled "Success"
- `[data-role='filter-failed']`: class `btn btn-sm btn-ghost`, labeled "Failed"

### Scenario 6 — Empty state when no history

skip

The QA account had existing sync history entries (Google Ads, Google Analytics, Facebook Ads), so the empty state card ("No sync history yet.") was not displayed. The page rendered sync history entries correctly instead. The empty state path was not testable without a fresh account with no history.

### Scenario 7 — BDD spec suite (criteria 4762–4773)

pass

All 12 BDD specs passed:
- Criterion 4762: pass — 1 test, 0 failures
- Criterion 4763: pass — 1 test, 0 failures
- Criterion 4764: pass — 1 test, 0 failures
- Criterion 4765: pass — 1 test, 0 failures
- Criterion 4766: pass — 1 test, 0 failures
- Criterion 4767: pass — 1 test, 0 failures
- Criterion 4768: pass — 1 test, 0 failures
- Criterion 4769: pass — 1 test, 0 failures
- Criterion 4770: pass — 1 test, 0 failures
- Criterion 4771: pass — 1 test, 0 failures
- Criterion 4772: pass — 1 test, 0 failures
- Criterion 4773: pass — 1 test, 0 failures

### Scenario 8 — Filter interaction

pass

- Clicked `[data-role='filter-success']`: button gained `btn-primary` class, `[data-status='failed']` elements were removed from the DOM.
- Clicked `[data-role='filter-failed']`: button gained `btn-primary` class, `[data-status='success']` elements were removed from the DOM.
- Clicked `[data-role='filter-all']`: button regained `btn-primary` class.

### Scenario 9 — Google Ads appears on connect page (criterion 4765)

pass

Navigating to `/integrations/connect` showed the Google provider card with the description "Google Ads and Google Analytics". No standalone "Connect Google Ads" button exists separate from the Google integration. The page lists Google as a single unified provider covering both Google Ads and Google Analytics.

## Evidence

- `.code_my_spec/qa/510/screenshots/01-sync-history-page.png`
- `.code_my_spec/qa/510/screenshots/02-schedule-section.png`
- `.code_my_spec/qa/510/screenshots/03-date-range.png`
- `.code_my_spec/qa/510/screenshots/04-filter-tabs.png`
- `.code_my_spec/qa/510/screenshots/05-sync-entries-present.png`
- `.code_my_spec/qa/510/screenshots/06-filter-success-active.png`
- `.code_my_spec/qa/510/screenshots/07-connect-page-google-ads.png`

## Issues

None
