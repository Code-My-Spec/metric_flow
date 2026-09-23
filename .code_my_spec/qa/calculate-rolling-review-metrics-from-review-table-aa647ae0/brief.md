# QA Story Brief

Story 515 — Calculate Rolling Review Metrics from Review Table

Tests the ProviderDashboard at `/integrations/google_business/dashboard` which surfaces
review metrics in a platform-agnostic provider dashboard. Verifies the dashboard loads
with review data, shows metric cards, sync history, and handles user interactions.

## Tool

web (MCP browser tools — vibium)

## Auth

Log in as the QA owner user via the password form. Credentials: `qa@example.com` / `hello world!`

## Seeds

Verify login works. The QA user should have a `google_business` integration from prior OAuth flow.

## What To Test

### Scenario 1 — Authenticated access to GBP dashboard

- Navigate to `http://localhost:4070/integrations/google_business/dashboard`
- Expected: page loads with "Google Business" in heading and "Dashboard" text
- Expected: Connected badge visible
- Screenshot the loaded dashboard
- Maps to AC: "dashboard accessible to authenticated user with connected integration"

### Scenario 2 — Dashboard shows review metrics (platform-agnostic)

- On the GBP dashboard
- Check for metric cards (`[data-role='metric-card']`)
- Check for review-related content (review_count, review_rating)
- Expected: metrics displayed without platform-specific gating text
- Screenshot the metrics section

### Scenario 3 — Reviews section visible for GBP

- On the GBP dashboard
- Check for `[data-role='reviews-section']` — reviews section should be present for google_business
- Screenshot the reviews section

### Scenario 4 — Sync history section

- On the GBP dashboard
- Check for `[data-role='sync-history-section']`
- If sync history exists, verify `[data-role='sync-history-row']` elements
- Screenshot the sync history section

### Scenario 5 — Sync Now button

- On the GBP dashboard
- Check for `[data-role='sync-now']` button
- Click it and verify flash message "Sync started"
- Screenshot after clicking

### Scenario 6 — Date range selector

- On the GBP dashboard
- Verify date range options are present (Last 7 days, Last 30 days, etc.)
- Screenshot the action bar

### Scenario 7 — Unauthenticated access blocked

- Clear cookies
- Navigate to `/integrations/google_business/dashboard`
- Expected: redirected to `/users/log-in`
- Screenshot

### Scenario 8 — Empty state for unconnected provider

- Navigate to a provider dashboard where no integration exists (e.g., `/integrations/facebook_ads/dashboard`)
- Expected: empty state with `[data-role='empty-state']` and connect link
- Screenshot

## Result Path

`.code_my_spec/qa/515/result.md`
