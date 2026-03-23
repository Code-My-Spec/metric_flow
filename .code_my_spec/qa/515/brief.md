# QA Story Brief

Story 515 — Calculate Rolling Review Metrics from Review Table

Tests that the reports page (`/reports`) is accessible to authenticated users, displays
review metrics in a platform-agnostic way, and blocks unauthenticated access. The story
covers the metric calculation backend (BUSINESS_REVIEW_DAILY_COUNT,
BUSINESS_REVIEW_TOTAL_COUNT, BUSINESS_REVIEW_AVERAGE_RATING) surfaced through the
`ReportLive.Index` LiveView at `/reports`.

## Tool

web (MCP browser tools — vibium)

## Auth

Log in as the QA owner user via the password form:

1. Launch browser: `mcp__vibium__browser_launch(headless: true)`
2. Navigate: `mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")`
3. Scroll password form into view: `mcp__vibium__browser_scroll(selector: "#login_form_password")`
4. Fill email: `mcp__vibium__browser_fill(selector: "#login_form_email", text: "qa@example.com")`
5. Fill password: `mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")`
6. Click submit: `mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")`
7. Wait for redirect: `mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)`
8. Verify: `mcp__vibium__browser_get_url()` should return `http://localhost:4070/`

Credentials: `qa@example.com` / `hello world!`

## Seeds

Verify seeds are in place by checking the login succeeds. If login fails, run:

```bash
cd /Users/johndavenport/Documents/github/metric_flow && mix run priv/repo/qa_seeds.exs
```

No story-specific seeds are required. The base QA seeds create the `qa@example.com` owner
user and "QA Test Account" which are sufficient to test the `/reports` page.

## What To Test

### Scenario 1 — Authenticated access to /reports

- Navigate to `http://localhost:4070/reports` after logging in
- Expected: page loads without redirect (HTTP 200, LiveView mounts)
- Expected: page heading "Reports" is visible
- Screenshot the loaded reports page
- Maps to AC: "report page loads for an authenticated user"

### Scenario 2 — Reports page shows review metrics content (platform-agnostic)

- On the `/reports` page after login
- Check page HTML contains "review" or "Review" text, OR contains `[data-role='review-metrics']`, OR contains `[data-role='reports']`
- Expected: the page surfaces review metrics without restricting them to a single named platform
- Check that the page does NOT contain text "Google Business Profile only", "Yelp only", or "Trustpilot only"
- Screenshot the metric summary strip if present (`[data-role='metric-summary']`)
- Maps to AC: "platform-agnostic — operates on Review table directly regardless of source platform"

### Scenario 3 — Review section heading is platform-neutral

- On the `/reports` page after login
- Check that the page contains "Reviews" or "Review Metrics" as a heading, OR contains `[data-role='review-metrics']`
- Expected: any review-related section label does not name a single platform
- Maps to AC: "review section heading does not reference a specific platform"

### Scenario 4 — Unauthenticated access is blocked

- Clear cookies: `mcp__vibium__browser_delete_cookies()`
- Navigate to `http://localhost:4070/reports` without logging in
- Expected: redirected away from `/reports` (to `/users/log-in` or similar)
- Screenshot the redirect destination
- Maps to AC: "unauthenticated user cannot access the reports page"

### Scenario 5 — Available Metrics strip (if review metrics exist)

- After login, navigate to `http://localhost:4070/reports`
- If `[data-role='metric-summary']` is present, inspect `[data-role='metric-badge']` elements
- Look for badges containing "BUSINESS_REVIEW_DAILY_COUNT", "BUSINESS_REVIEW_TOTAL_COUNT", or "BUSINESS_REVIEW_AVERAGE_RATING"
- If no review metrics are present (empty metric list), note this as informational — the
  backend calculation may not have been triggered yet (no review sync has run)
- Maps to AC: "All three metrics are persisted as Metric rows keyed as BUSINESS_REVIEW_*"

## Setup Notes

This story tests both the reporting UI (`ReportLive.Index`) and the underlying metric
calculation system. The BDD spec (`criterion_4798`) focuses on the reports page being
accessible and displaying review content in a platform-agnostic way.

The BUSINESS_REVIEW_* metric keys are computed after a review sync runs. In the base QA
seed environment no review sync has been triggered, so `[data-role='metric-summary']` may
not render (the `:if={@metric_names != []}` guard in the template). This is expected
behavior — Scenario 5 should note the absence and continue without failing.

The core acceptance criteria tested here are: (1) authenticated access works, (2) the
page does not gate review content behind a single platform name, (3) unauthenticated
users are blocked. The rebuild-on-sync and rolling calculation accuracy criteria are
covered by unit/integration tests and can be noted as out of scope for browser QA.

## Result Path

`.code_my_spec/qa/515/result.md`
