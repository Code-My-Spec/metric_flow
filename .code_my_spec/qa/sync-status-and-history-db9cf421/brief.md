# QA Story Brief

Story 439: Sync Status and History — test the `/integrations/sync-history` LiveView for schedule display, sync history entries, real-time broadcasts, filtering, and error highlighting.

## Tool

web (Vibium MCP browser tools)

## Auth

Run seeds first, then launch browser and log in as the QA owner:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run the base QA seeds before testing. No story-specific seeds are required — the sync history page works for any authenticated user, even one with no sync records (empty state is a valid test condition).

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

Credentials after seeding:

- Owner: `qa@example.com` / `hello world!`
- URL: `http://localhost:4070/users/log-in`

## What To Test

### Scenario 1: Page loads and shows sync schedule (AC: next scheduled sync time)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify the page title "Sync History" is visible
- Verify the `[data-role='sync-schedule']` section is present
- Verify it contains "Automated Sync Schedule" heading
- Verify it contains "Daily at 2:00 AM UTC" text
- Verify it shows a "Daily" badge (`[data-role='sync-schedule'] .badge-info`)
- Take a screenshot: `01-sync-schedule.png`

### Scenario 2: Empty state when no sync history exists (AC: detailed sync history)

- Remain on `http://localhost:4070/integrations/sync-history` (seeded user has no sync records)
- Verify the `[data-role='sync-history']` container is present
- Verify "No sync history yet." text is visible
- Verify no `[data-role='sync-history-entry']` elements exist
- Take a screenshot: `02-empty-state.png`

### Scenario 3: Filter controls are present (AC: filter by status)

- Remain on `http://localhost:4070/integrations/sync-history`
- Verify the "All" filter button is visible (`[data-role='filter-all']`)
- Verify the "Success" filter button is visible (`[data-role='filter-success']`)
- Verify the "Failed" filter button is visible (`[data-role='filter-failed']`)
- Verify the "All" button is active (has `btn-primary` class) since it is the default filter
- Take a screenshot: `03-filter-controls.png`

### Scenario 4: Date range section is present

- Remain on `http://localhost:4070/integrations/sync-history`
- Verify `[data-role='date-range']` section is present
- Verify it contains "Showing data through" text
- Verify it contains yesterday's date in ISO format (e.g., `2026-03-05`)
- Take a screenshot: `04-date-range.png`

### Scenario 5: Unauthenticated redirect

- Quit and relaunch a fresh browser (or clear cookies)
- Navigate directly to `http://localhost:4070/integrations/sync-history` without logging in
- Verify the page redirects to `/users/log-in` (URL should contain `/users/log-in`)
- Take a screenshot: `05-unauth-redirect.png`
- Log back in as `qa@example.com` before continuing

### Scenario 6: Success entry shows timestamp, status, and records synced (AC: timestamp, status, records synced)

This scenario requires persisted sync history data. Since the seed script does not create sync history records, use the Elixir console approach below, OR accept that the live-event path (via `handle_info`) is the mechanism to validate in a browser QA context. The live-event path cannot be triggered from the browser directly — it requires sending a message to the LiveView pid. Therefore, this scenario should be tested against the page by observing the persisted DB path requires additional seed data.

To seed a sync history record for the QA user, run:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run -e '
alias MetricFlow.{Repo, Users}
alias MetricFlow.Users.{Scope, UserToken}
alias MetricFlow.Integrations.Integration
alias MetricFlow.DataSync.{SyncJob, SyncHistory}

user = Users.get_user_by_email("qa@example.com")

integration =
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google_ads,
    access_token: "qa-test-token",
    expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
    granted_scopes: [],
    provider_metadata: %{}
  })
  |> Repo.insert!()

sync_job =
  %SyncJob{}
  |> SyncJob.changeset(%{
    user_id: user.id,
    integration_id: integration.id,
    provider: :google_ads,
    status: :completed
  })
  |> Repo.insert!()

%SyncHistory{}
|> SyncHistory.changeset(%{
  user_id: user.id,
  integration_id: integration.id,
  sync_job_id: sync_job.id,
  provider: :google_ads,
  status: :success,
  records_synced: 342,
  started_at: ~U[2026-03-04 02:00:00Z],
  completed_at: ~U[2026-03-04 02:03:00Z]
})
|> Repo.insert!()

%SyncHistory{}
|> SyncHistory.changeset(%{
  user_id: user.id,
  integration_id: integration.id,
  sync_job_id: sync_job.id,
  provider: :google_ads,
  status: :failed,
  records_synced: 0,
  error_message: "API rate limit exceeded",
  started_at: ~U[2026-03-03 02:00:00Z],
  completed_at: ~U[2026-03-03 02:01:00Z]
})
|> Repo.insert!()

IO.puts("Sync history seeded.")
'
```

After running that command, reload the sync history page and continue with the following checks.

### Scenario 7: Persisted success entry displays correctly (AC: timestamp, status, records synced)

- Navigate to `http://localhost:4070/integrations/sync-history`
- Verify a `[data-role='sync-history-entry'][data-status='success']` element is present
- Verify "Google Ads" provider name appears in `[data-role='sync-provider']`
- Verify "Success" badge (`badge-success`) is visible
- Verify "342 records synced" text is visible
- Verify a "Completed at" label with the timestamp is present (expected: "Mar 04, 2026 02:03 UTC")
- Take a screenshot: `06-success-entry.png`

### Scenario 8: Persisted failed entry is highlighted with error details (AC: failed syncs highlighted)

- Remain on `http://localhost:4070/integrations/sync-history`
- Verify a `[data-role='sync-history-entry'][data-status='failed']` element is present
- Verify "Failed" badge (`badge-error`) is visible
- Verify the error message "API rate limit exceeded" appears in `[data-role='sync-error']`
- Take a screenshot: `07-failed-entry.png`

### Scenario 9: Filter by "Failed" shows only failed entries (AC: filter by status)

- Click the "Failed" filter button (`[data-role='filter-failed']`)
- Wait for the page to update
- Verify only failed entries are shown — no success entries should be visible
- Verify "API rate limit exceeded" error message is visible
- Verify "342 records synced" text is NOT visible
- Take a screenshot: `08-filter-failed.png`

### Scenario 10: Filter by "Success" shows only success entries (AC: filter by status)

- Click the "Success" filter button (`[data-role='filter-success']`)
- Wait for the page to update
- Verify only success entries are shown
- Verify "342 records synced" text is visible
- Verify "API rate limit exceeded" error message is NOT visible
- Take a screenshot: `09-filter-success.png`

### Scenario 11: Filter "All" restores full list (AC: filter by status)

- Click the "All" filter button (`[data-role='filter-all']`)
- Wait for the page to update
- Verify both the success entry and the failed entry are visible again
- Verify "342 records synced" text is visible
- Verify "API rate limit exceeded" text is visible
- Take a screenshot: `10-filter-all.png`

## Setup Notes

The BDD spec files use a `:owner_with_integrations` shared given that is not present in `test/support/shared_givens.ex`. This is a gap in the test infrastructure — the specs reference a given step that has not been implemented. This should be noted as a QA scope issue if the spex tests fail due to the missing given.

The sync history page renders two kinds of entries: persisted `SyncHistory` records from the database (shown on mount) and live `sync_events` prepended in real time via `handle_info` messages. The browser-based QA path can only test the DB-persisted path, which requires the seed command in Scenario 6 above. The real-time event path (`handle_info` broadcasts) is exercised by the unit tests in `sync_history_test.exs`.

The page is behind `require_authenticated_user` — always log in before navigating to `/integrations/sync-history`.

## Result Path

`.code_my_spec/qa/439/result.md`
