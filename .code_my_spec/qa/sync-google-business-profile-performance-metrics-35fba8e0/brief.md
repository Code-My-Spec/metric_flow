# QA Story Brief

Story 517: Sync Google Business Profile Performance Metrics

## Tool

web (Vibium MCP browser tools for `/integrations/sync-history` LiveView)

## Auth

Log in as the seeded QA owner user via the password form:

1. Launch browser: `mcp__vibium__browser_launch(headless: true)`
2. Navigate: `mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")`
3. Scroll password form into view: `mcp__vibium__browser_scroll(selector: "#login_form_password")`
4. Fill email: `mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")`
5. Fill password: `mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")`
6. Click submit: `mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")`
7. Wait for redirect: `mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)`
8. Verify URL is `http://localhost:4070/` — if login fails, run seeds first

## Seeds

Verify login works before running seeds. If `qa@example.com` login succeeds, seeds are in place.

If login fails:
```
mix run priv/repo/qa_seeds.exs
```

No story-specific seeds are needed. Story 517 is a backend sync integration — the sync history page displays data from PubSub events (sent by the sync worker at runtime) and from the `sync_history` DB table. QA testing covers the page structure and provider display behavior, not the actual sync execution. The seeded QA account owner with no sync history will show the empty state, which is valid for testing the page skeleton and unauthenticated redirect.

## Setup Notes

Story 517 implements the Google Business Profile Performance API sync, a backend data pipeline job. The user-facing component is the existing `/integrations/sync-history` LiveView (story 509 component). The BDD specs test by sending `{:sync_completed, ...}` and `{:sync_failed, ...}` PubSub messages directly to the LiveView process using `send/2` — this is a test-layer technique that cannot be replicated in browser automation.

What browser QA can verify:
- The sync history page loads and renders correctly for an authenticated user
- Unauthenticated users are redirected to `/users/log-in`
- The schedule section correctly describes Google-relevant provider coverage
- The `google_business` provider is NOT in the `@provider_names` map in `SyncHistory` — it falls through to `derive_display_name/1` which would render it as "Google Business" — this gap should be checked
- Filter tabs (All, Success, Failed) are present with correct `data-role` attributes
- The empty state renders correctly when no history exists

Critical gap identified from source review: `SyncHistory.@provider_names` only lists `google_ads`, `facebook_ads`, `google_analytics`, `google_search_console`, `quickbooks`, and `google`. The `:google_business` and `:google_business_reviews` providers are absent. The schedule description also does not mention Google Business Profile. These are implementation gaps to test and report.

Additionally, run `mix spex test/spex/517_sync_google_business_profile_performance_metrics/` to execute all BDD spec files, which can fully test the sync event handling by sending messages to the LiveView process in the test environment.

## What To Test

### Scenario 1: Unauthenticated redirect (AC: all)

- Visit `http://localhost:4070/integrations/sync-history` without being logged in
- Use curl: `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history`
- Expected: HTTP 302 redirect
- Screenshot: capture the redirect response code

### Scenario 2: Sync history page loads for authenticated user (AC: display)

- Navigate to `http://localhost:4070/integrations/sync-history` while logged in as `qa@example.com`
- Expected: page renders with H1 "Sync History" and subtitle "View automated sync results and status"
- Screenshot: full page after load

### Scenario 3: Schedule section content and provider coverage (AC: 4817, 4819)

- On the sync history page, inspect `[data-role="sync-schedule"]`
- Expected: contains "Automated Sync Schedule" heading
- Expected: description mentions "Google Ads", "Facebook Ads", "Google Analytics", "QuickBooks"
- VERIFY: does the description mention "Google Business Profile" or "mybusiness"? Per the source it does NOT — the schedule text is static and was written before this integration. This is likely a bug.
- Screenshot: schedule section

### Scenario 4: Date range section (AC: display)

- On the sync history page, inspect `[data-role="date-range"]`
- Expected: shows text "Showing data through {yesterday's date} (yesterday — today excluded, incomplete day)"
- Screenshot: date range section

### Scenario 5: Filter tabs present with correct data-role attributes (AC: 4825, 4826)

- On the sync history page, verify filter tabs exist
- Expected: button `[data-role="filter-all"]` labeled "All" is present and active (has `btn-primary` class)
- Expected: button `[data-role="filter-success"]` labeled "Success" is present
- Expected: button `[data-role="filter-failed"]` labeled "Failed" is present
- Click "Success" filter — verify it becomes `btn-primary` and "All" reverts to `btn-ghost`
- Click "Failed" filter — verify it becomes `btn-primary`
- Click "All" filter — verify it returns to `btn-primary`
- Screenshot: filter tabs in each active state

### Scenario 6: Empty state when no sync history exists (AC: 4821 — first sync label)

- With no prior sync history for the seeded account, verify the empty state is shown
- Expected: `[data-role="sync-history"]` contains text "No sync history yet."
- Expected: secondary text mentioning "Initial Sync" entries
- Expected: `[data-sync-type="initial"]` badge labeled "Initial Sync" is present
- Screenshot: empty state

### Scenario 7: google_business provider display name gap (AC: 4817, 4819, 4820, 4827)

- Inspect the `SyncHistory` source at `lib/metric_flow_web/live/integration_live/sync_history.ex`
- Verify that `@provider_names` does NOT include `:google_business` or `:google_business_reviews`
- This means the provider falls through to `derive_display_name/1` which produces "Google Business" (acceptable) and "Google Business Reviews" (acceptable)
- However, the omission from `@provider_names` is an intentional gap to flag — the BDD specs expect "Google Business" to appear, and the `derive_display_name` path would produce that
- Report this as a low-severity informational finding

### Scenario 8: Run mix spex for full BDD coverage (all AC)

Run the BDD spec suite to test the actual sync event handling in the test environment:

```bash
cd /Users/johndavenport/Documents/github/metric_flow && mix spex test/spex/517_sync_google_business_profile_performance_metrics/
```

Expected: all 11 spec files pass. Each spec sends `{:sync_completed, ...}` or `{:sync_failed, ...}` directly to the LiveView process, verifying:
- `google_business` provider name appears (criteria 4817, 4818, 4819, 4820)
- Success badge and record counts appear (criteria 4819, 4820, 4821, 4823)
- `Initial Sync` badge appears when `sync_type: :initial` (criterion 4821)
- Error details appear in failed entries with `[data-role="sync-error"]` (criteria 4817, 4818, 4826)
- Filter tabs work to isolate success/failed entries (criteria 4825, 4826)
- `google_business_reviews` produces a separate entry from `google_business` (criterion 4827)
- Null/missing metric values produce success entries with same record count (criterion 4823)
- Two consecutive sync entries appear without overlap (criterion 4822)

Record pass/fail count and any failures with exact error output.

## Result Path

`.code_my_spec/qa/517/result.md`
