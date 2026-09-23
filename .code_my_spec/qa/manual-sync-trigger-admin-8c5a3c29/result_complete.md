# QA Result

Story 438 — Manual Sync Trigger (Admin)

## Status

fail

## Scenarios

### Scenario 1 — Sync Now button visible on connected integration

pass

Navigated to `http://localhost:4070/integrations`. The page rendered a "Connected Platforms" section containing three cards: Google Analytics, Google Ads, and Facebook Ads. Each connected card contained a "Sync Now" button (`button[phx-click="sync"]`).

Evidence: `.code_my_spec/qa/438/screenshots/01-integrations-page.png`

### Scenario 2 — Available platforms do NOT show Sync Now

pass

The Available Platforms section contained only a QuickBooks card (`[data-role='integration-card'][data-status='available']`). That card had no `button[phx-click="sync"]` element — only a "Connect QuickBooks" link button was present.

Evidence: `.code_my_spec/qa/438/screenshots/02-sync-button-enabled.png`

### Scenario 3 — Sync Now button is enabled before clicking

pass

Before any interaction, `browser_is_enabled` on `button[phx-click="sync"]` returned `true`. No `disabled` attribute was present on any Sync Now button. No `.badge-warning` or `.loading-spinner` was present on initial page load.

### Scenario 4 — Clicking Sync Now triggers flash confirmation

pass

Clicked `[data-platform='google_analytics'] button[phx-click='sync']`. A flash message appeared: "Sync started for Google Analytics". The platform name in the flash matched the card that was clicked.

Note: A second flash appeared almost immediately: "Sync failed for Google: All data providers failed. Check your integration settings." The sync worker completes (and fails) extremely quickly in dev because the `qa_test_token` access token is not a real credential. The first flash ("Sync started for...") did appear as required by criterion 4051.

Evidence: `.code_my_spec/qa/438/screenshots/03-after-sync-click.png`

### Scenario 5 — Button is disabled after clicking Sync Now

fail

After clicking Sync Now, the `[data-platform='google_analytics'] button[phx-click='sync']` did NOT receive a `disabled` attribute. `browser_is_enabled` returned `true` immediately after the click. The button was never observed in a disabled state.

The `disabled={MapSet.member?(@syncing, platform.key)}` attribute is present in the template at line 134 of `integration_live/index.ex`, so the mechanism exists. However, the sync worker runs synchronously in the BEAM and fails before the client receives the first LiveView re-render diff that would show the disabled state. `handle_event("sync", ...)` returns `{:noreply, socket}` with the `@syncing` MapSet updated, but `handle_info({:sync_failed, ...})` clears that MapSet before the first diff reaches the client.

Expected: button disabled while sync in progress.
Actual: button never disabled.

### Scenario 6 — Syncing badge appears while sync is in progress

fail

After clicking Sync Now, no `.badge-warning` element appeared and `[data-role="integration-sync-status"]` spans remained empty. No `.loading-spinner` was present. The template at line 95 of `integration_live/index.ex` renders a "Syncing" badge when `MapSet.member?(@syncing, platform.key)` is true, but the sync worker clears the `@syncing` assign via `handle_info({:sync_failed, ...})` before the intermediate render is delivered to the browser.

Evidence: `.code_my_spec/qa/438/screenshots/04-sync-failure-no-loading-state.png`

### Scenario 7 — No Syncing badge before clicking

pass

On fresh page load before triggering any sync, no `.badge-warning` or `.loading-spinner` was present in the DOM. All `[data-role="integration-sync-status"]` spans were empty.

### Scenario 8 — After sync completes, Syncing indicator gone and button re-enabled

pass (trivially — button was never disabled and badge never appeared)

After reloading the integrations page following the sync attempt, no syncing badge was present, no `disabled` attribute was on any Sync Now button, and all three integration cards remained in the Connected state. No sync result badge with records count appeared because the sync failed rather than completing successfully.

Evidence: `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png`

### Scenario 9 — After sync, integration still shows Connected status

pass

After the manual sync attempt on the Google Analytics card, all three integration cards retained `data-status="connected"` and the `badge-success` "Connected" badge was visible on each. The sync failure did not alter the integration's connection state.

Evidence: `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png`

### Scenario 10 — Unauthenticated access redirects to login

pass

Launched a fresh browser session (no cookies) and navigated to `http://localhost:4070/integrations`. The browser was immediately redirected to `http://localhost:4070/users/log-in`. Also confirmed via curl: unauthenticated request returns `302`.

Evidence: `.code_my_spec/qa/438/screenshots/06-unauthenticated-redirect.png`

## Evidence

- `.code_my_spec/qa/438/screenshots/01-integrations-page.png` — full-page view of integrations index: three connected cards with Sync Now buttons; QuickBooks in Available section with no Sync Now
- `.code_my_spec/qa/438/screenshots/02-sync-button-enabled.png` — Sync Now buttons present and enabled on connected cards; Available section has no Sync Now
- `.code_my_spec/qa/438/screenshots/03-after-sync-click.png` — after clicking Sync Now on Google Analytics: "Sync started for Google Analytics" flash and "Sync failed for Google" flash both visible; button not disabled
- `.code_my_spec/qa/438/screenshots/04-sync-failure-no-loading-state.png` — immediately after sync click: no Syncing badge, no disabled button, sync status spans empty
- `.code_my_spec/qa/438/screenshots/05-connected-status-preserved.png` — after page reload: all three cards remain Connected (badge-success), Sync Now buttons re-enabled, no syncing badge
- `.code_my_spec/qa/438/screenshots/06-unauthenticated-redirect.png` — fresh browser session redirected to /users/log-in when accessing /integrations

## Issues

### Sync Now button never enters disabled/in-progress state

#### Severity
HIGH

#### Scope
app

#### Description
After clicking "Sync Now", the button does not become disabled and no "Syncing" badge appears in the `[data-role="integration-sync-status"]` span. Criteria 4051 and 4052 require a visible loading state while sync is in progress.

The `disabled={MapSet.member?(@syncing, platform.key)}` binding and the Syncing badge conditional are present in `lib/metric_flow_web/live/integration_live/index.ex` (lines 95 and 134). The mechanism is implemented but the timing does not work: `handle_event("sync", ...)` assigns the platform key to `@syncing` and returns `{:noreply, socket}`, but the sync worker fails synchronously in the same BEAM process so `handle_info({:sync_failed, ...})` fires and removes the key from `@syncing` before the intermediate LiveView diff reaches the browser.

The `phx-disable-with="Please wait..."` attribute only disables the button for the round-trip duration of the `phx-click` event itself — not for the duration of the background job. Once `handle_event` returns, LiveView re-enables the button even though the sync worker has not finished.

To reproduce: click "Sync Now" on any connected integration card at `http://localhost:4070/integrations`. The button never shows as disabled and the Syncing badge never appears. Both the "Sync started for..." and "Sync failed for..." flashes appear nearly simultaneously.

### Sync failure flash message says "All data providers failed" — unclear to end users

#### Severity
LOW

#### Scope
app

#### Description
When sync fails, the error flash reads: "Sync failed for Google: All data providers failed. Check your integration settings." The phrase "All data providers failed" is technically accurate but not user-friendly — it doesn't explain what to check or what "data providers" means. A more actionable message would reference the specific provider and suggest reconnecting or refreshing the OAuth token.

The message is generated by `build_failure_message/2` in `lib/metric_flow_web/live/integration_live/index.ex` (line 412).

Also note: the error message uses the provider name ("Google") rather than the platform name ("Google Analytics"), which is inconsistent with the success flash "Sync started for Google Analytics". This can be ambiguous since one Google OAuth connection covers both Google Analytics and Google Ads.
