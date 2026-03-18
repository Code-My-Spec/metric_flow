# QA Story Brief

Story 510: Sync Google Ads Data

Testing the SyncHistory LiveView at `/integrations/sync-history`. This story covers backend Google Ads sync behavior as it surfaces in the sync history UI. The BDD specs exercise the LiveView by navigating to the page, then verifying how the page renders sync events (both success and failure). Since the backend sync runs asynchronously and requires real Google Ads API credentials, browser-based testing focuses on: the sync schedule section mentions Google Ads, the page structure (filter tabs, schedule card, date range), unauthenticated redirect, and the visual rendering of success and failure states by triggering PubSub-style broadcasts via `mix spex`.

## Tool

web

## Auth

Launch a browser and log in via the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

Verify seeds are in place by attempting login. If login succeeds, seeds are already installed. If login fails:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

No additional story-specific seeds are needed. The sync history page does not require a pre-existing integration to render — it shows an empty state or live-broadcast events.

Run the BDD specs using:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix spex test/spex/510_sync_google_ads_data/
```

## What To Test

### Scenario 1 — Unauthenticated redirect

- Visit `http://localhost:4070/integrations/sync-history` without logging in
- Expected: redirected to `/users/log-in`

### Scenario 2 — Page loads for authenticated user

- Navigate to `http://localhost:4070/integrations/sync-history` after logging in
- Expected: H1 "Sync History", subtitle "View automated sync results and status"
- Screenshot: `01-sync-history-page.png`

### Scenario 3 — Sync schedule section (criteria 4762, 4766, 4767, 4768, 4769)

- On the sync history page, locate the `[data-role='sync-schedule']` card
- Expected text: "Automated Sync Schedule"
- Expected text: "Google Ads" listed as a covered marketing provider
- Expected text: "Daily at 2:00 AM UTC"
- Expected text: "backfill" or "historical" (confirms first-sync backfill behavior is described)
- Expected text: "3 times" and "backoff" (confirms retry behavior is described)
- Expected badge: "Daily" with `badge-info` class
- Screenshot: `02-schedule-section.png`

### Scenario 4 — Date range section

- On the sync history page, locate the `[data-role='date-range']` element
- Expected: shows yesterday's date in ISO 8601 format and the "(yesterday — today excluded, incomplete day)" explanation
- Screenshot: `03-date-range.png`

### Scenario 5 — Filter tabs present

- On the sync history page, verify filter tabs render:
  - `[data-role='filter-all']` button labeled "All" with `btn-primary` class (default active state)
  - `[data-role='filter-success']` button labeled "Success" with `btn-ghost` class
  - `[data-role='filter-failed']` button labeled "Failed" with `btn-ghost` class
- Screenshot: `04-filter-tabs.png`

### Scenario 6 — Empty state when no history

- If no sync history exists for the QA account, the page shows an empty state card:
  - Text: "No sync history yet."
  - Text mentioning "Initial Sync" entries
  - Badge `[data-sync-type='initial']` labeled "Initial Sync" with `badge-ghost` class
- Screenshot: `05-empty-state.png`

### Scenario 7 — BDD spec suite for sync event rendering (criteria 4762–4773)

Run the full BDD spec suite and record pass/fail per criterion:

```bash
mix spex test/spex/510_sync_google_ads_data/
```

Each spec:
- Registers a fresh user, logs in, opens the sync history LiveView
- Sends a `{:sync_completed, ...}` or `{:sync_failed, ...}` message to the LiveView PID
- Asserts that the page renders `[data-role='sync-history-entry']` with the correct `data-status`, provider name, record count, error text, or "Initial Sync" badge

Key assertions across criteria:
- 4762: `data-status="success"` entry appears, shows "Google Ads", shows record count (42)
- 4763: Multiple per-account sync events each produce a distinct `sync-history-entry`
- 4764: Failed entry with `DEVELOPER_TOKEN_NOT_APPROVED` error text is visible in `[data-role='sync-error']`
- 4765: Success entry appears without requiring a separate OAuth connect button for Google Ads specifically
- 4766: Entry with `data_date` shows 5 records synced (one per metric: clicks, impressions, cost, all_conversions, conversions)
- 4767: No campaign or ad group text in entry; only 2 entries when 2 dates are sent (not more)
- 4768: No Device/Network dimension text; `data_date` value appears in ISO format
- 4769: Initial backfill event (548 records, `sync_type: :initial`) shows "Initial Sync" badge; incremental event does NOT show "Initial Sync"
- 4770: Failed entry with `attempt: 3, max_attempts: 3` shows "Attempt 3/3"; specific error text (503/UNAVAILABLE) is visible
- 4771: Failed entry with `customerId: 9876543210` and `CUSTOMER_NOT_ENABLED` shows those values in `[data-role='sync-error']`
- 4772: Failed filter hides success entries; two failure events both appear; full error text from `reason` is rendered
- 4773: Success entry with cost-related payload renders correctly; `[data-role='sync-history-entry']` is present

### Scenario 8 — Filter interaction (browser)

- On the sync history page with any sync entries present, click `[data-role='filter-success']`
- Expected: "Success" button gains `btn-primary`, shows only `data-status="success"` entries
- Click `[data-role='filter-failed']`
- Expected: "Failed" button gains `btn-primary`, shows only `data-status="failed"` entries
- Click `[data-role='filter-all']`
- Expected: "All" button gains `btn-primary`, all entries visible
- Screenshot: `06-filter-success-active.png`

### Scenario 9 — Google Ads appears on connect page (criterion 4765)

- Navigate to `http://localhost:4070/integrations/connect`
- Expected: "Google Ads" text is present on the page (listed under the Google platform)
- Expected: no standalone "Connect Google Ads" button separate from the Google integration
- Screenshot: `07-connect-page-google-ads.png`

## Setup Notes

All BDD specs for this story test the SyncHistory LiveView's real-time message handling. The specs do not actually trigger a real Google Ads API call — they send synthesized `{:sync_completed, ...}` and `{:sync_failed, ...}` messages directly to the LiveView process. This is the correct test pattern because:

1. Google Ads API credentials (GOOGLE_DEVELOPER_TOKEN, GOOGLE_MANAGER_ACCOUNT_ID) are environment-level secrets not available in the QA environment.
2. The SyncHistory LiveView renders whatever `reason` string is in the payload, so the display logic can be verified independently of the backend sync.

The browser-based scenarios (1–6, 8–9) verify the static page structure. The BDD spec suite (scenario 7) exercises the full LiveView event-handling and rendering pipeline. Record both sets of results.

## Result Path

`.code_my_spec/qa/510/result.md`
