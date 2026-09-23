# QA Result

Story 438 — Manual Sync Trigger (Admin)

## Status

fail

## Scenarios

### Scenario 1 — Sync Now button visible on connected integration

pass

Navigated to `http://localhost:4070/integrations`. The "Connected Platforms" section was visible with a Google card (`[data-role="integration-card"][data-platform="google"]`). The card contained a `button[phx-click="sync"]` with text "Sync Now". The "Available Platforms" section was present with Facebook Ads showing `data-status="available"` and only a "Connect" button — no "Sync Now" button on available platform cards.

Evidence: `.code_my_spec/qa/438/screenshots/01-integrations-page-initial.png`

### Scenario 2 — Sync Now button is enabled when no sync is in progress

pass

The `button[phx-click="sync"]` on the Google integration card was enabled (not disabled) on initial page load. `browser_is_enabled` returned `true`.

Evidence: `.code_my_spec/qa/438/screenshots/02-sync-button-enabled.png`

### Scenario 3 — Clicking Sync Now triggers sync and shows loading state

pass

Clicked the "Sync Now" button on the Google card. The LiveView re-rendered and:
- A flash message "Sync started for Google" appeared at the bottom of the page
- The "Sync Now" button became disabled (`browser_is_enabled` returned `false`)
- A "Syncing" badge (`.badge-warning`) appeared inside `[data-role="integration-sync-status"]`
- A `.loading-spinner` element was present inside the sync status area

Evidence: `.code_my_spec/qa/438/screenshots/03-sync-in-progress.png`

### Scenario 4 — Success state after sync completes

fail

After clicking "Sync Now", the page entered the "Syncing" state and remained there indefinitely. After waiting 10 seconds, no `{:sync_completed, ...}` message arrived, the "Syncing" badge never disappeared, the button remained disabled, and no success flash appeared.

Root cause: The `handle_event("sync", ...)` handler in `IntegrationLive.Index` (line 264-278) only updates local LiveView state (`@syncing` MapSet) and shows a flash message. It does NOT call `DataSync.sync_integration/2` or start any worker. Because no worker is started, no `{:sync_completed, ...}` or `{:sync_failed, ...}` message is ever sent to the LiveView PID, so the "Syncing" spinner state is permanent once entered.

Evidence: `.code_my_spec/qa/438/screenshots/04-sync-stuck-syncing-state.png`, `.code_my_spec/qa/438/screenshots/04b-sync-never-completes.png`

### Scenario 5 — Connected status preserved after manual sync

pass (partial)

After reloading the integrations page, the Google integration card retained `data-status="connected"` with a "Connected" badge, no `[data-status="disconnected"]` element existed inside the card, and the "Sync Now" button was present and re-enabled (page reload clears the in-memory `@syncing` MapSet). The integration itself was not disconnected by the sync attempt.

Evidence: `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png`

Note: Because Scenario 4 failed (sync never completes), this scenario was validated by reloading the page rather than waiting for post-sync completion. The Connected status is preserved at the database level.

### Scenario 6 — Unauthenticated user cannot access the integrations page

pass

Launched a fresh browser session (no cookies) and navigated directly to `http://localhost:4070/integrations`. The browser was redirected to `http://localhost:4070/users/log-in`. The URL was confirmed with `browser_get_url`.

Evidence: `.code_my_spec/qa/438/screenshots/06-unauthenticated-redirect.png`

## Evidence

- `.code_my_spec/qa/438/screenshots/01-integrations-page-initial.png` — Integrations page with Google connected and Facebook Ads available
- `.code_my_spec/qa/438/screenshots/02-sync-button-enabled.png` — Sync Now button in enabled state before any sync
- `.code_my_spec/qa/438/screenshots/03-sync-in-progress.png` — After clicking Sync Now: Syncing badge, spinner, disabled button, and flash
- `.code_my_spec/qa/438/screenshots/04-sync-stuck-syncing-state.png` — Syncing state still active after 10 seconds (no completion)
- `.code_my_spec/qa/438/screenshots/04b-sync-never-completes.png` — Continued stuck syncing state confirming no worker completion
- `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png` — Google integration still Connected after page reload
- `.code_my_spec/qa/438/screenshots/06-unauthenticated-redirect.png` — Redirect to login for unauthenticated access to /integrations

## Issues

### Sync Now button never triggers actual data sync — UI enters permanent Syncing state

#### Severity
HIGH

#### Description
The `handle_event("sync", ...)` handler in `MetricFlowWeb.IntegrationLive.Index` (lines 264-278 of `lib/metric_flow_web/live/integration_live/index.ex`) updates the LiveView's `@syncing` MapSet and shows the "Sync started for Google" flash, but it does not call `DataSync.sync_integration/2` or start any Oban worker.

As a result:
1. The "Syncing" spinner and disabled button state appear immediately after clicking — this is correct UI behavior.
2. No `{:sync_completed, ...}` or `{:sync_failed, ...}` message is ever sent to the LiveView PID.
3. The "Syncing" spinner and disabled button state are permanent for the duration of the LiveView session. The user cannot click "Sync Now" again without reloading the page.
4. No actual data is synced from any external platform.

The fix is to call `DataSync.sync_integration(scope, provider)` inside the `handle_event("sync", ...)` handler. On `{:ok, _sync_job}`, the LiveView should add the provider to `@syncing`. The `SyncWorker` should then send `{:sync_completed, ...}` or `{:sync_failed, ...}` to the LiveView PID when the Oban job finishes.

Reproduced at: `http://localhost:4070/integrations` — click "Sync Now" on any connected integration and observe the spinner never resolves.
