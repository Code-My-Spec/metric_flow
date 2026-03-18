# QA Story Brief

Story 511: Sync Facebook Ads Data

## Tool

web (vibium MCP browser tools for LiveView pages)

## Auth

Launch the browser and log in as the QA owner:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

## Seeds

Verify seeds are in place by attempting login. If login succeeds, no re-seeding is needed.

If login fails (user does not exist), run:

```bash
mix run priv/repo/qa_seeds.exs
```

This story does not require story-specific seeds beyond the base QA users. The sync history
page tests use browser navigation only — no Facebook Ads integration needs to be connected
in the database for the sync event scenarios (the LiveView handles PubSub broadcasts in
memory). However, for criterion 4775 (act_ prefix), a Facebook Ads integration with
account IDs must be visible on the integrations page. The base seeds do not include a
Facebook Ads integration, so that scenario can only be verified structurally (the page
renders and shows the integration card without act_ prefix) if one exists from a prior QA
run, or skipped with a note.

## What To Test

Most of these scenarios test the `/integrations/sync-history` LiveView and the
`/integrations/connect` page. The core behaviors are:

1. Facebook Ads is listed as a provider in the schedule section
2. Sync history entries for Facebook Ads show correctly on success and failure
3. Filter tabs (All / Success / Failed) work correctly
4. The connect page lists Facebook Ads as a separate platform from Google
5. Unauthenticated users are redirected to login

### Scenario 1: Sync history page loads and shows Facebook Ads in the schedule section (criteria 4774, 4778)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Capture screenshot
- Verify the page heading "Sync History" is present
- Verify the schedule section (`data-role="sync-schedule"`) text mentions "Facebook Ads" explicitly
- Verify the schedule description says "Daily at 2:00 AM UTC"
- Verify the `.badge.badge-info` labeled "Daily" is present
- Verify the date range section (`data-role="date-range"`) shows yesterday's date in ISO 8601 format
- Verify the filter tabs are present: All, Success, Failed buttons with `data-role` attributes `filter-all`, `filter-success`, `filter-failed`

### Scenario 2: Empty state shows when no sync history exists (criteria 4774, 4786)

- If the sync history list is empty (no persisted records and no live events), verify:
  - "No sync history yet." text is shown
  - The empty state mentions "Initial Sync" with `data-sync-type="initial"` badge

### Scenario 3: Unauthenticated access redirects to login (all criteria)

- Log out by clearing cookies: `mcp__vibium__browser_delete_cookies()`
- Use curl to check the redirect:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history
  ```
- Expected: 302 redirect (not 200)
- Navigate to `http://localhost:4070/integrations/sync-history` in the browser without auth
- Verify the browser is redirected to `/users/log-in`
- Capture screenshot as evidence

### Scenario 4: Facebook Ads is a separate platform on the connect page (criterion 4776)

After re-authenticating:

- Navigate to `http://localhost:4070/integrations/connect`
- Capture screenshot
- Verify the page lists "Facebook" or "Facebook Ads" as a platform
- Verify the page lists "Google" as a separate platform
- Verify there is a connect button with `data-platform='facebook_ads'` and `data-role='connect-button'`
- Verify there is a connect button with `data-platform='google'` and `data-role='connect-button'`
- Verify the Facebook Ads connect button has `phx-value-provider='facebook_ads'`
- Verify the Google connect button has `phx-value-provider='google'`
- The two providers have independent connect buttons, confirming separate OAuth flows

### Scenario 5: Facebook Ads provider detail page shows Facebook branding (criterion 4776)

- Navigate to `http://localhost:4070/integrations/connect/facebook_ads`
- Capture screenshot
- Verify the page shows "Facebook" branding
- Verify the page does NOT show "Connect Google" or "Google Analytics"

### Scenario 6: Sync history shows a success entry for Facebook Ads (criteria 4774, 4777, 4778)

Note: The sync history LiveView handles `{:sync_completed, payload}` messages sent to the
LiveView process in real time. Browser testing cannot send Elixir process messages directly.
To verify live event rendering, navigate to the page and check if any persisted sync history
entries exist for Facebook Ads from prior runs. If no persisted entries exist, the page should
show the empty state.

- Navigate to `http://localhost:4070/integrations/sync-history`
- Capture full-page screenshot
- If persisted Facebook Ads entries exist:
  - Verify each entry has `data-role="sync-history-entry"`
  - Verify successful entries have `data-status="success"` and show "Success" badge
  - Verify `data-role="sync-provider"` shows "Facebook Ads"
  - Verify records synced count is shown (e.g., "N records synced")
  - Verify entries do not show campaign, adset, or ad segmentation fields (criterion 4777)
  - Verify entries do not show "Polly", "cassette", or "record/replay" text (criterion 4785)
- If no entries exist, document this in the result with the empty state screenshot

### Scenario 7: Filter tabs work — Success and Failed filters (criterion 4786)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Click the "Failed" button (`data-role="filter-failed"`)
- Capture screenshot
- Verify the Failed button becomes the active/primary button
- Verify only failed entries are shown (or empty state if none)
- Click the "Success" button (`data-role="filter-success"`)
- Capture screenshot
- Verify the Success button is now active
- Click the "All" button (`data-role="filter-all"`)
- Verify the All button returns to active state

### Scenario 8: Failed Facebook Ads sync entries show error details (criteria 4784, 4786)

- If any persisted failed entries exist for Facebook Ads:
  - Verify `data-status="failed"` on the entry card
  - Verify "Failed" badge is shown
  - Verify `data-role="sync-error"` element is present with the error message
  - Verify the error message is specific (not just "Something went wrong")
  - Capture screenshot

### Scenario 9: Integrations page shows Facebook Ads account IDs without act_ prefix (criterion 4775)

- Navigate to `http://localhost:4070/integrations`
- Capture screenshot
- If a Facebook Ads integration exists, verify:
  - The account IDs displayed do NOT have the "act_" prefix in the UI
  - The account IDs shown are plain numeric strings

### Scenario 10: Sync history page shows initial sync badge (criterion 4783)

- Navigate to `http://localhost:4070/integrations/sync-history`
- If any entries exist with `sync_type: :initial` (initial backfill), verify:
  - The "Initial Sync" badge is shown (`data-sync-type="initial"`)
- If no initial sync entries exist, note this in the result

## Setup Notes

This story covers the Facebook Ads data sync pipeline, which is primarily a backend/data
concern. Most acceptance criteria (4774–4785) describe sync worker behavior that is not
directly observable through the UI without live sync events occurring. The linked component
`MetricFlowWeb.IntegrationLive.SyncHistory` is the primary UI surface.

The BDD spex files use `given_ :owner_with_integrations` and send process messages directly
to the LiveView PID — a pattern only available in ExUnit. Browser-based QA tests instead
verify the rendered state of the page and any persisted sync history entries in the database.

Key things observable via browser:
- Schedule section mentions "Facebook Ads" as a covered provider
- Filter tabs function correctly
- Persisted sync history entries render correctly (provider name, status, records, error)
- Unauthenticated redirect works
- Connect page shows Facebook Ads as a separate platform from Google with correct data attributes

Things NOT directly testable via browser without triggering a real sync or injecting process
messages:
- The actual `account.getInsights()` API call behavior (criterion 4774)
- The act_ prefix being added at call time (criterion 4775 — only the storage side is verifiable)
- Retry behavior with backoff (criterion 4784)
- Polly not appearing in production (criterion 4785 — can verify absence of text in static page)
- 180-day backfill triggering (criterion 4783 — only the sync_type badge is observable if an entry exists)

## Result Path

`.code_my_spec/qa/511/result.md`
