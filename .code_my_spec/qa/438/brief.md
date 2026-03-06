# QA Story Brief

Story 438 — Manual Sync Trigger (Admin)

## Tool

web (vibium MCP browser tools for LiveView page at `/integrations`)

## Auth

Run the start-qa script to seed users, then log in via the browser:

```
./.code_my_spec/qa/scripts/start-qa.sh
```

Then in vibium:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password", direction: "down")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials: `qa@example.com` / `hello world!`

## Seeds

The base QA seeds create a user and team account but no connected integrations. This story requires a connected integration to appear on the `/integrations` page. The BDD spex use the `:owner_with_integrations` shared given, which directly inserts an integration via `MetricFlowTest.IntegrationsFixtures` in test context.

For browser testing, create a connected integration by running a story-specific seed:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
mix run -e '
alias MetricFlow.{Repo, Users, Integrations}
alias MetricFlow.Users.Scope
alias MetricFlow.Integrations.Integration

user = Users.get_user_by_email("qa@example.com")
scope = Scope.for_user(user)

existing = Integrations.list_integrations(scope) |> Enum.find(&(&1.provider == :google))

unless existing do
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google,
    access_token: "qa_test_access_token",
    refresh_token: "qa_test_refresh_token",
    expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
    granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "selected_accounts" => ["UA-12345 (Main Site)", "GA4-67890 (App)"]
    }
  })
  |> Repo.insert!()
  IO.puts("Created Google integration for qa@example.com")
else
  IO.puts("Google integration already exists for qa@example.com")
end
'
```

After running seeds, note the QA user ID for any scenario-specific assertions.

## Setup Notes

The "Sync Now" button in the source (line 106 in `integration_live/index.ex`) fires `phx-click="sync"` with `phx-value-provider={platform.key}`. The button is disabled when the provider is in `@syncing_providers` (a MapSet). The sync flow:

1. User clicks "Sync Now" -> `handle_event("sync", ...)` calls `DataSync.sync_integration/2`
2. On `{:ok, _sync_job}`, the button disables and a flash "Sync started for Google" appears
3. When the async sync worker finishes, it sends `{:sync_completed, ...}` or `{:sync_failed, ...}` to the LiveView PID
4. On completion, the syncing badge and spinner disappear; the button re-enables; a success/error flash shows

In browser testing, the async completion (`{:sync_completed, ...}`) is sent by the actual `DataSync` worker process. The outcome depends on whether `DataSync.sync_integration/2` returns `{:ok, _}` in the dev environment with a stub access token. Verify the flash message and button state after clicking Sync Now. If the worker completes immediately in dev, check the success flash within a few seconds.

The BDD spex (criterion 4053 and 4054) simulate the async messages by sending `{:sync_completed, ...}` / `{:sync_failed, ...}` directly to `context.view.pid` — this is not reproducible via browser automation. Those scenarios are best validated via `mix spex` against the unit-level spex files.

The available platforms section shows cards with `data-status="available"` and a "Connect" button (not "Sync Now") — verify the absence of "Sync Now" on those cards.

## What To Test

### Scenario 1 — Sync Now button visible on connected integration (criterion 4050)

1. Navigate to `http://localhost:4070/integrations`
2. Capture a screenshot of the full integrations page
3. Assert: the "Connected Platforms" section is present with a "Google" card
4. Assert: the Google card (`[data-role="integration-card"][data-platform="google"]`) contains a "Sync Now" button (`button[phx-click="sync"]` with text "Sync Now")
5. Assert: the "Available Platforms" section is present with cards that have `data-status="available"`
6. Assert: the available platform cards do NOT contain a "Sync Now" button (only a "Connect" button)

### Scenario 2 — Sync Now button is enabled when no sync is in progress (criterion 4050)

1. On the integrations page (from Scenario 1)
2. Assert: `button[phx-click="sync"]` with text "Sync Now" does NOT have the `disabled` attribute
3. Capture a screenshot showing the enabled button

### Scenario 3 — Clicking Sync Now triggers sync and shows loading state (criteria 4051, 4052)

1. On the integrations page, click the "Sync Now" button on the Google card
2. Wait briefly for LiveView to re-render
3. Capture a screenshot immediately after clicking
4. Assert: a flash message containing "Sync started for Google" appears at the top of the page
5. Assert: the "Sync Now" button (`button[phx-click="sync"]`) is now disabled
6. Assert: a "Syncing" badge is visible on the Google integration card (`[data-role="integration-sync-status"]` containing text "Syncing")
7. Assert: the loading spinner element is present (`.loading-spinner` inside `[data-role="integration-sync-status"]`)

### Scenario 4 — Success state after sync completes (criterion 4053)

1. After clicking Sync Now (from Scenario 3), wait a few seconds for the async sync worker to complete (or poll the page)
2. Capture a screenshot of the post-sync state
3. Assert: the page shows a success flash containing either the count of records synced, the word "Synced", or a timestamp (year)
4. Assert: the "Syncing" badge with spinner is no longer present
5. Assert: the "Sync Now" button is re-enabled (no `disabled` attribute)
6. Assert: the integration still shows a "Connected" badge (`badge-success` with text "Connected")

### Scenario 5 — Connected status preserved after manual sync (criterion 4055)

1. After sync completion, look at the Google integration card
2. Assert: `[data-role="integration-card"][data-platform="google"]` still contains `[data-status="connected"]` with text "Connected"
3. Assert: no `[data-status="disconnected"]` element exists inside the Google card
4. Assert: the "Sync Now" button is still present on the page (available for future syncs)
5. Capture a final screenshot confirming Connected status and available Sync Now button

### Scenario 6 — Unauthenticated user cannot access the integrations page

1. In a new browser session (no cookies), navigate to `http://localhost:4070/integrations`
2. Assert: redirected to `/users/log-in` (check URL with `mcp__vibium__browser_get_url`)
3. Capture a screenshot of the redirect destination

## Result Path

`.code_my_spec/qa/438/result.md`
