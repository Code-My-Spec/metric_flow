# QA Story Brief

Story 438 — Manual Sync Trigger (Admin)

## Tool

web (vibium MCP browser tools — this is a LiveView page)

## Auth

Log in as the QA owner user using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

After `wait_for_url` confirms the redirect, navigate to `/integrations` to begin testing. Do NOT use `wait(selector: "body")` after the login click — it times out during the HTTP redirect.

## Seeds

The base seeds create a Google integration for `qa@example.com`. Verify seeds are in place by logging in successfully — if login works, seeds are already set. Only run seeds if login fails:

```bash
# Only run if login fails (server not running):
mix run priv/repo/qa_seeds.exs

# Only run if login fails (server IS already running):
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Expected seed state for this story:
- `qa@example.com` — owner of "QA Test Account", has a connected Google integration (`provider: :google`)
- The Google integration provides two data platforms: Google Analytics and Google Ads
- Both platforms appear in the Connected Platforms section at `/integrations`

## What To Test

### Scenario 1 — Sync Now button visible on connected integration (criterion 4050)

- Navigate to `http://localhost:4070/integrations`
- Verify the page shows a "Connected Platforms" section containing at least one card
- Verify at least one card has a "Sync Now" button (`button` with text "Sync Now")
- Screenshot: `01-integrations-page.png`

### Scenario 2 — Available (unconnected) platforms do NOT show Sync Now (criterion 4050)

- On the same integrations page, locate the "Available Platforms" section
- Verify cards in `[data-role='integration-card'][data-status='available']` do NOT contain a "Sync Now" button
- Screenshot: `02-sync-button-enabled.png` (showing enabled Sync Now on connected, absent on available)

### Scenario 3 — Sync Now button is enabled before clicking (criterion 4050)

- Verify the "Sync Now" button in the connected section has no `disabled` attribute before any sync action
- The selector `button[phx-click='sync']` should exist and not have `disabled`

### Scenario 4 — Clicking Sync Now triggers flash confirmation (criterion 4051)

- Click the "Sync Now" button on a connected integration card (`button[phx-click='sync']`)
- Wait for the flash message to appear
- Verify the flash message contains "Sync started for" followed by the platform name (e.g., "Sync started for Google Analytics")
- Screenshot: `03-after-sync-click.png`

### Scenario 5 — Button is disabled after clicking Sync Now (criterion 4051)

- After clicking Sync Now in Scenario 4, verify the same button now has a `disabled` attribute
- The selector `[data-platform='google_analytics'] button[phx-click='sync'][disabled]` should be present

### Scenario 6 — Syncing badge appears while sync is in progress (criterion 4052)

- After clicking Sync Now, verify the integration card shows a "Syncing" badge
- Verify the badge has class `badge-warning`
- Verify a loading spinner is present: `[data-role='integration-sync-status'] .loading-spinner`
- Screenshot: `04-sync-failure-no-loading-state.png` (capture the loading state if visible, or the post-sync state)

### Scenario 7 — No Syncing badge before clicking (criterion 4052)

- On a fresh page load (before triggering any sync), verify no "Syncing" text or `.loading-spinner` is present

### Scenario 8 — After sync completes, Syncing indicator gone and button re-enabled (criterion 4053)

- After triggering a sync and waiting for completion (the sync worker runs asynchronously), reload the integrations page
- Verify the "Syncing" badge is gone
- Verify the "Sync Now" button is no longer disabled (no `disabled` attribute)
- If a sync result is shown, verify it contains records synced count and a timestamp
- Screenshot: `05-connected-status-preserved.png`

### Scenario 9 — After sync, integration still shows Connected status (criterion 4055)

- After completing a manual sync (or after the sync attempt), verify:
  - The integration card still shows `[data-status='connected']`
  - The "Connected" badge (`badge-success` with text "Connected") is still present
  - No disconnected or error state is shown on the Google Analytics card
- This confirms manual sync does not change the integration connection state
- Screenshot: `05-connected-status-preserved.png` (same screenshot can serve as evidence)

### Scenario 10 — Unauthenticated access redirects to login (general auth check)

- Clear cookies and navigate directly to `http://localhost:4070/integrations`
- Verify redirect to the login page (`/users/log-in`)
- Screenshot: `06-unauthenticated-redirect.png`

## Setup Notes

The sync trigger calls `DataSync.sync_integration/2` which enqueues a background sync job. In dev/test, the sync worker runs and completes asynchronously — results may appear on the page after a short delay (or on page reload). The LiveView subscribes to PubSub topic `user:{user_id}:sync` and updates when it receives `{:sync_completed, ...}` or `{:sync_failed, ...}` messages.

The "Sync Now" button uses `phx-click="sync"` with `phx-value-platform` (e.g., `google_analytics`) and `phx-value-provider` (e.g., `google`). The button is rendered once per connected platform. Since both Google Analytics and Google Ads share the `google` provider, both appear in the connected section when a Google integration exists — click the button on either card.

If the sync worker returns an error (provider not fully configured in dev, or API key issues), the flash will show an error message — record that as a finding but do not fail the test for Scenario 4 if the flash message text is "Integration not found." (this indicates the dev integration is not fully wired, which is a known issue to report).

The base seeds include a Google integration with `access_token: "qa_test_token"` — actual API calls will fail in dev without a real token. The important things to verify are the UI behaviors: button presence, disabled state, flash messages, and badge rendering.

## Result Path

`.code_my_spec/qa/438/result.md`
