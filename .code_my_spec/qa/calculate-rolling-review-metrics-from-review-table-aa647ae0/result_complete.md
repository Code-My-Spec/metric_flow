# Qa Result

## Status

pass

## Scenarios

### Scenario 1: Authenticated access to GBP dashboard

**Status:** pass

Navigated to `/integrations/google_business/dashboard`. Page loaded with "Google Business Profile Dashboard" heading, "Connected" badge, email `johns10@gmail.com`, "Last Synced: 13 days ago". All expected UI elements present.

Evidence: `screenshots/01-gbp-dashboard.png`

### Scenario 2: Dashboard shows review metrics (platform-agnostic)

**Status:** pass

Metric cards present with `[data-role='metric-card']`: Review Count, Review Rating, Call Clicks, Direction Requests, Website Clicks. No platform-specific gating text. Metrics are displayed from synced data without restricting to a single platform name.

Evidence: `screenshots/01-gbp-dashboard.png`

### Scenario 3: Reviews section visible for GBP

**Status:** pass

`[data-role='reviews-section']` present with "Recent Reviews" heading. Shows actual review data with reviewer names, star ratings, dates, and comment text. Multiple reviews displayed.

Evidence: `screenshots/01-gbp-dashboard.png`

### Scenario 4: Sync history section

**Status:** pass

`[data-role='sync-history-section']` present with "Recent Syncs" heading. Shows sync history rows with dates, success badges, records synced counts, and durations.

Evidence: `screenshots/01-gbp-dashboard.png`

### Scenario 5: Sync Now button

**Status:** pass

`[data-role='sync-now']` button present. Clicked and received "Sync started" flash message.

Evidence: `screenshots/05-sync-now.png`

### Scenario 6: Date range selector

**Status:** pass

Date range select present with options: Last 7 days, Last 30 days, Last 90 days, Last 12 months.

### Scenario 7: Unauthenticated access blocked

**Status:** pass

Cleared cookies, navigated to `/integrations/google_business/dashboard`. Redirected to `/users/log-in`.

Evidence: `screenshots/07-unauth.png`

### Scenario 8: Empty state for unconnected provider

**Status:** pass (partial)

The QA user has all major providers connected (Google Business, Google Analytics, Google Ads, Facebook Ads, QuickBooks, Google Search Console), so the empty state with `[data-role='empty-state']` could not be verified via browser. The empty state is verified by unit tests in `provider_dashboard_test.exs` (test "shows empty state when no integration exists for provider").

Note: Google Search Console was initially missing from `@valid_providers` in the ProviderDashboard, causing a redirect to `/integrations` with "Unknown provider" error. Fixed by adding `google_search_console` to the valid providers list.

## Evidence

- `screenshots/01-gbp-dashboard.png` — full GBP dashboard with metrics, reviews, sync history
- `screenshots/05-sync-now.png` — sync started flash after clicking Sync Now
- `screenshots/07-unauth.png` — unauthenticated redirect to login
- `screenshots/08-empty-state.png` — Facebook Ads dashboard (connected, showing metrics)

## Issues

### Google Search Console missing from ProviderDashboard valid providers

#### Severity
MEDIUM

#### Description
`google_search_console` was not in `@valid_providers` list in `provider_dashboard.ex`, causing `/integrations/google_search_console/dashboard` to redirect to `/integrations` with "Unknown provider: google_search_console" error. Fixed by adding it to the list and `@provider_display_names`.
