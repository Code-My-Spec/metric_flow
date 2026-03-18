# QA Story Brief

Story 513 — Sync Google Business Profile Reviews

## Tool

web (vibium MCP browser tools — `/integrations/sync-history` is a LiveView page behind session auth)

## Auth

Log in as the QA owner user via the password form:

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

The base seeds provide a confirmed `qa@example.com` owner user and a QA Test Account. If login succeeds, seeds are already in place and no re-seeding is needed.

If login fails (user not found), run seeds once:

```bash
mix run priv/repo/qa_seeds.exs
```

No story-specific seeds are required. Story 513 tests the Sync History LiveView's response to broadcast events — no actual Google Business API calls or pre-existing sync history records are needed.

## What To Test

All scenarios test the `/integrations/sync-history` LiveView. The page does not trigger any real sync calls during testing — it simply receives `{:sync_completed, payload}` and `{:sync_failed, payload}` PubSub messages and renders them. The BDD specs verify that the LiveView correctly handles `google_business_reviews` as a provider.

Since browser testing cannot send Elixir process messages directly, the focus is on the page's static content, filter behavior, and any persisted sync history entries. Where real-time event injection is not possible via the browser, verify the page structure matches what the spex assertions require.

### Scenario 1 — Page loads and shows sync schedule (AC: API coverage description)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Screenshot the full page
- Verify the H1 reads "Sync History"
- Verify the schedule card (`data-role="sync-schedule"`) is present
- Verify the schedule description mentions "Google Business Profile" — the `sync_history.ex` source includes it in the list of covered providers
- Verify the "Daily" badge is shown (`badge-info`)
- Verify the date range section (`data-role="date-range"`) shows yesterday's date
- Capture screenshot: `01-sync-history-page-load.png`

### Scenario 2 — Provider name mapping for google_business_reviews (AC: provider name display)

- Remain on `/integrations/sync-history`
- Get the full page HTML
- Verify the `@provider_names` map in the source includes `google_business_reviews: "Google Business Reviews"` — confirmed at line 27 of `sync_history.ex`
- The empty-state card should read "No sync history yet." if there are no sync records
- Capture screenshot: `02-empty-state-or-history.png`

### Scenario 3 — Filter tabs are rendered and functional (AC: filtering by status)

- On `/integrations/sync-history`
- Verify three filter buttons are present: All (`data-role="filter-all"`), Success (`data-role="filter-success"`), Failed (`data-role="filter-failed"`)
- Verify the "All" button is active (has `btn-primary` class) by default
- Click the "Success" button
- Verify it becomes active (gains `btn-primary`)
- Click the "Failed" button
- Verify it becomes active
- Click "All" to restore
- Capture screenshot: `03-filter-tabs.png`

### Scenario 4 — Unauthenticated access is redirected (AC: auth guard)

- Run `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/sync-history` — expect `302`
- Capture as a note in the result (no screenshot needed for curl check)

### Scenario 5 — Persisted sync history entries render correctly if present (AC: entry display)

- On `/integrations/sync-history`
- Get the HTML and check for any `data-role="sync-history-entry"` elements
- If entries exist, verify each shows a `data-role="sync-provider"` span, a status badge (`.badge-success`, `.badge-error`, or `.badge-warning`), and for success entries a "records synced" count
- If a `google_business_reviews` persisted entry exists, verify its provider name renders as "Google Business Reviews" (not the raw atom string)
- Capture screenshot: `05-persisted-entries.png`

### Scenario 6 — Full-rebuild failure error format (AC: midway failure description)

- If any persisted failed entries are shown, click the "Failed" filter
- Verify the failed entry is shown and the "Success" entries are hidden
- Click "All" to restore
- Capture screenshot: `06-failed-filter.png`

### Scenario 7 — run `mix spex` to execute the BDD specs

Run the full spex suite for this story to verify all eleven criteria pass at the unit/integration level:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix spex test/spex/513_sync_google_business_profile_reviews/
```

Record the output. Note any failures separately from browser observations.

## Setup Notes

Story 513 is a backend sync story whose observable UI surface is exclusively the Sync History LiveView (`/integrations/sync-history`). The acceptance criteria describe internal sync behavior (API calls, database writes, aggregation). These are tested at the spex level (criterion 4787–4797) which send broadcast messages directly to the LiveView process.

Browser testing covers the structural requirements: page renders, provider name mapping, filter tab behavior, entry display format, auth guard, and schedule description. The spex tests cover real-time event handling and entry rendering in detail.

The provider name `google_business_reviews` maps to `"Google Business Reviews"` in `@provider_names` at line 27 of `lib/metric_flow_web/live/integration_live/sync_history.ex`. The schedule description at line 53 of the same file lists "Google Business Profile" as a covered provider.

## Result Path

`.code_my_spec/qa/513/result.md`
