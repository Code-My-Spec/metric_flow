# QA Result

Story 438 — Manual Sync Trigger (Admin)

## Status

fail

## Scenarios

### Scenario 1 — Sync Now button visible on connected integration

PASS

Navigated to `http://localhost:4070/integrations`. The page rendered a "Connected Platforms" section with three cards: Google Analytics, Google Ads, and Facebook Ads. Each card contained a "Sync Now" button (`button[phx-click="sync"]`). The seed data has a Google integration (provider: :google) and Facebook Ads integration, which is the expected state per the brief.

Evidence: `01-integrations-page.png`

### Scenario 2 — Available platforms do NOT show Sync Now

PASS

The QuickBooks card has `data-status="available"` and contains no `button[phx-click="sync"]` element — only a "Connect QuickBooks" link button is present. `browser_find_all(selector: '[data-role="integration-card"][data-status="available"] button[phx-click="sync"]')` returned no elements.

Evidence: `02-sync-button-enabled.png`

### Scenario 3 — Sync Now button is enabled before clicking

PASS

Before any interaction, `[data-platform="google_analytics"] button[phx-click="sync"]` was found and `browser_is_enabled` returned `true`. No `disabled` attribute was present on any Sync Now button at page load.

### Scenario 4 — Clicking Sync Now triggers flash confirmation

PASS

Clicked `[data-platform="google_analytics"] button[phx-click="sync"]`. An alert-role element appeared containing "Sync started for Google Analytics". The flash message correctly references the platform name (not the provider name). The sync completed successfully — a "Synced 186 records at 2026-03-17 16:14 UTC" badge appeared on both Google Analytics and Google Ads cards, since they share the Google provider.

Evidence: `03-after-sync-click.png`

### Scenario 5 — Button is disabled after clicking Sync Now

FAIL

After clicking Sync Now, `browser_is_enabled(selector: '[data-platform="google_analytics"] button[phx-click="sync"]')` returned `true` — the button was not disabled. No `disabled` attribute was ever observed on the button, even immediately after clicking.

Root cause: The sync worker runs (or completes its initial phase) fast enough in the dev environment that `handle_info({:sync_completed, ...})` fires and clears `@syncing` before the first LiveView re-render diff reaches the client. The template's `disabled={MapSet.member?(@syncing, platform.key)}` logic is correct, but the intermediate "disabled" state is never painted in the browser.

Expected: `[data-platform="google_analytics"] button[phx-click="sync"]` should be disabled while sync is in progress.
Actual: Button remains enabled throughout the sync lifecycle.

### Scenario 6 — Syncing badge appears while sync is in progress

FAIL

After clicking Sync Now, no `.badge-warning` element appeared and no `.loading-spinner` was present in `[data-role="integration-sync-status"]`. The page went directly from the initial state to the post-sync success badge state ("Synced 186 records"), skipping the intermediate "Syncing" state entirely.

The Syncing badge code (`MapSet.member?(@syncing, platform.key)`) is never observed in the rendered HTML due to the same race condition as Scenario 5.

Evidence: `04-sync-failure-no-loading-state.png` — screenshot immediately after click shows no Syncing badge; the sync result badge is already rendered.

### Scenario 7 — No Syncing badge before clicking

PASS

On a fresh page load before triggering any sync, no `.badge-warning` or `.loading-spinner` was present in the DOM. The sync status area was empty as expected.

### Scenario 8 — After sync completes, Syncing indicator gone and button re-enabled

PASS

After sync completed (via PubSub `{:sync_completed, ...}` message), the page showed no Syncing badge, the Sync Now button was enabled, and a success badge was visible: "Synced 186 records at 2026-03-17 16:14 UTC" on both the Google Analytics and Google Ads cards. Records synced count and timestamp are both present.

Evidence: `05-connected-status-preserved.png`

### Scenario 9 — After sync, integration still shows Connected status

PASS

After manual sync completion, both the Google Analytics and Google Ads cards retained `data-status="connected"` and the "Connected" badge (`badge-success`) remained visible. No disconnected or error state was shown. The manual sync did not alter the integration's connection state.

Evidence: `05-connected-status-preserved.png`

### Scenario 10 — Unauthenticated access redirects to login

PASS

Launched a fresh browser session with no cookies and navigated to `http://localhost:4070/integrations`. The browser was redirected to `http://localhost:4070/users/log-in`. Confirmed via `browser_get_url()` returning the login URL.

Evidence: `06-unauthenticated-redirect.png`

## Evidence

- `.code_my_spec/qa/438/screenshots/01-integrations-page.png` — full-page view of integrations index showing Connected Platforms (Google Analytics, Google Ads, Facebook Ads) and Available Platforms (QuickBooks), with Sync Now buttons on connected cards
- `.code_my_spec/qa/438/screenshots/02-sync-button-enabled.png` — same full-page view confirming no Sync Now button on available (QuickBooks) card
- `.code_my_spec/qa/438/screenshots/03-after-sync-click.png` — after clicking Sync Now on Google Analytics; flash "Sync started for Google Analytics" visible, sync result badge already rendered
- `.code_my_spec/qa/438/screenshots/04-sync-failure-no-loading-state.png` — immediately after sync click; no Syncing badge or disabled button, sync result badge already present
- `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png` — full-page after sync; Connected badge present, Sync Now button enabled, records synced badge shown
- `.code_my_spec/qa/438/screenshots/06-unauthenticated-redirect.png` — fresh browser session redirected to login page when accessing /integrations
- `.code_my_spec/qa/438/screenshots/s1-integrations-full-page.png` — initial page load before any interaction

## Issues

### Sync Now button never enters disabled state during sync

#### Severity
HIGH

#### Description
After clicking "Sync Now", the button does not become disabled. Criteria 4051 and 4052 require a visible loading/in-progress state while sync is in progress.

The template correctly has `disabled={MapSet.member?(@syncing, platform.key)}` and the `handle_event("sync", ...)` handler correctly adds the platform key to `@syncing` before returning. However, the sync worker completes (or sends a PubSub completion message) fast enough in the dev environment that `handle_info({:sync_completed, ...})` fires and removes the key from `@syncing` before the intermediate re-render is sent to the client. The client only ever receives the post-sync state.

The `phx-disable-with="Please wait..."` attribute is also insufficient for this use case — it only disables the button for the duration of the LiveView event round-trip (until the server returns from `handle_event`), not for the duration of the background job.

Reproduced at `http://localhost:4070/integrations` by clicking "Sync Now" on the Google Analytics card. Immediate check of `browser_is_enabled` after the click always returns `true`.

### Syncing badge never renders during sync

#### Severity
HIGH

#### Description
The "Syncing" badge (`.badge-warning` with "Syncing" text and a loading spinner) is never visible in the browser. The `[data-role="integration-sync-status"]` span goes directly from the empty state to the post-sync result badge ("Synced N records at timestamp"), with no observable intermediate Syncing state.

This is the same race condition as above: `@syncing` is populated then immediately cleared before the client renders the intermediate state. Criteria 4052 requires the UI to show a sync-in-progress indicator.

Reproduced at `http://localhost:4070/integrations` — after clicking Sync Now, no `.badge-warning` element appears in the DOM at any observable point.
