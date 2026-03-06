# QA Result

Story 438 — Manual Sync Trigger (Admin)

## Status

fail

## Scenarios

### Scenario 1 — Sync Now button visible on connected integration

**Result: pass**

Navigated to `http://localhost:4070/integrations` as `qa@example.com` with a seeded Google integration. The "Connected Platforms" section rendered the Google card with a visible "Sync Now" button (`button[phx-click="sync"]` with `phx-value-provider="google"`).

The "Available Platforms" section was present but empty — no `data-status="available"` cards rendered. This is expected in dev: only the `:google` provider is configured in `oauth_providers`, and it has a connected integration, so nothing appears in the available section. The absence of "Sync Now" on available cards was not testable via browser in this configuration (the connected-only layout means the available section is empty). The BDD criterion tested this via test-environment provider overrides.

Screenshot: `screenshots/01_integrations_page_initial.png`

### Scenario 2 — Sync Now button is enabled when no sync is in progress

**Result: pass**

Inspected the outer HTML of `button[phx-click='sync']` before clicking:

```html
<button phx-click="sync" phx-value-provider="google" class="btn btn-ghost btn-sm">
  Sync Now
</button>
```

No `disabled` attribute present. `mcp__vibium__browser_is_enabled` returned `true`. Button is correctly enabled when idle.

Screenshot: `screenshots/02_sync_now_button_enabled.png`

### Scenario 3 — Clicking Sync Now triggers sync and shows loading state

**Result: pass**

Clicked `button[phx-click='sync']`. After the LiveView re-rendered:

- Flash message "Sync started for Google" appeared at the bottom of the page.
- The "Sync Now" button changed to `disabled=""`.
- A "Syncing" badge with class `badge-warning` and `data-role="integration-sync-status"` appeared on the Google card.
- A loading spinner (`<span class="loading loading-spinner loading-xs ml-1">`) was present inside the Syncing badge.

All loading-state expectations from criteria 4051 and 4052 confirmed present immediately after click.

Screenshot: `screenshots/03_after_sync_now_clicked.png`

### Scenario 4 — Success state after sync completes

**Result: fail**

After clicking Sync Now, the "Syncing" badge and disabled button persisted indefinitely. The page was polled for 15 seconds; no `{:sync_completed, ...}` message was received by the LiveView and no success flash appeared.

Root cause identified via source code inspection:

1. `SyncWorker.provider_for(:google)` returns `{:error, :unsupported_provider}` — the `:google` atom is not in the worker's provider map (only `:google_analytics`, `:google_ads`, `:facebook_ads`, and `:quickbooks` are handled).
2. `SyncWorker.perform/1` never sends `{:sync_completed, ...}` or `{:sync_failed, ...}` back to the LiveView process. The worker updates the `SyncJob` database record but does not notify the LiveView. The LiveView's `handle_info` callbacks for these messages exist and are correct, but they are never triggered by the worker.

As a result, after clicking Sync Now the UI is permanently stuck in the "Syncing" state with a disabled button until the user refreshes the page.

Screenshot: `screenshots/04_syncing_stuck_no_completion.png`

### Scenario 5 — Connected status preserved after manual sync

**Result: not tested**

Could not be tested because Scenario 4 failed — the sync never completed, so the post-completion state was never reached. The "Syncing" badge remained on screen and the button stayed disabled.

### Scenario 6 — Unauthenticated user cannot access the integrations page

**Result: pass**

Launched a fresh browser session with no cookies and navigated to `http://localhost:4070/integrations`. The browser was redirected to `http://localhost:4070/users/log-in`. Confirmed via both `mcp__vibium__browser_get_url` and `curl -sv` (HTTP 302 with `location: /users/log-in`).

Screenshot: `screenshots/05_unauthenticated_redirect.png`

## Evidence

- `screenshots/01_integrations_page_initial.png` — Integrations page after login: Google card with Sync Now button, Connected badge, and selected accounts displayed
- `screenshots/02_sync_now_button_enabled.png` — Google integration card before clicking Sync Now; button enabled with no disabled attribute
- `screenshots/03_after_sync_now_clicked.png` — Immediately after clicking Sync Now: "Sync started for Google" flash, disabled button, "Syncing" badge with loading spinner
- `screenshots/04_syncing_stuck_no_completion.png` — Integrations page 15+ seconds after clicking Sync Now; still stuck in Syncing state with disabled button and no success/error message
- `screenshots/05_unauthenticated_redirect.png` — Fresh browser session redirected to /users/log-in when accessing /integrations unauthenticated

## Issues

### SyncWorker never sends sync completion or failure messages to the LiveView

#### Severity
HIGH

#### Description
`MetricFlow.DataSync.SyncWorker.perform/1` completes its work (updating the `SyncJob` database record to `:completed` or `:failed`) but never sends a `{:sync_completed, ...}` or `{:sync_failed, ...}` message to the LiveView process. The `IntegrationLive.Index` LiveView has correct `handle_info` callbacks for both messages (lines 317–343 in `lib/metric_flow_web/live/integration_live/index.ex`), but they are never invoked during a real sync because the worker does not send them.

As a result, clicking "Sync Now" permanently disables the button and shows the "Syncing" spinner until the user manually refreshes the page. Acceptance criteria 4053 (success message with timestamp and records synced) and 4054 (error details if sync fails) are completely unmet in the running application.

Reproduction: Log in as `qa@example.com`, navigate to `/integrations`, click "Sync Now" on the Google card. The page never transitions out of the "Syncing" state.

### SyncWorker does not handle the :google provider atom

#### Severity
HIGH

#### Description
`SyncWorker.provider_for/1` (line 127 in `lib/metric_flow/data_sync/sync_worker.ex`) only handles `:google_analytics`, `:google_ads`, `:facebook_ads`, and `:quickbooks`. When a sync is triggered for an integration with `provider: :google` (the provider key used by the OAuth integration fixture and the default `oauth_providers` config), the function returns `{:error, :unsupported_provider}`. The sync job silently fails with `:unsupported_provider` and no error is shown to the user.

This means the manual sync feature is completely non-functional for the `:google` provider that is the only provider available in the default dev configuration. Any sync triggered via the "Sync Now" button for a Google OAuth integration will silently fail at the worker level.

Reproduction: Seed a Google integration (provider: :google) and click "Sync Now". The Oban job runs but returns `{:error, :unsupported_provider}` without displaying any error to the user.
