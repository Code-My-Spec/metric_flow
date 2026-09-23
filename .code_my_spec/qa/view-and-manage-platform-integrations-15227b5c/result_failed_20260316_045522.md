# Qa Result

## Status

partial

## Scenarios

### Scenario 1: Unauthenticated redirect (AC: auth guard)

pass

Ran `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations` without authentication. Response was 302 — the route correctly redirects unauthenticated users.

### Scenario 2: Page loads with integration list heading (AC: view list)

pass

Navigated to `http://localhost:4070/integrations` as `qa@example.com`. The page loaded without redirect. Verified:
- `h1` contains "Integrations"
- `[data-role='integrations-list']` is present
- Three `[data-role='integration-card']` elements present (facebook_ads, google, quickbooks)
- "Connected Platforms" h2 is visible

Screenshot: `.code_my_spec/qa/436/screenshots/integrations-index.png`

### Scenario 3: Marketing platform name visible (AC: each integration shows platform name)

partial

`[data-role='integration-platform-name']` elements exist and contain platform names: "Facebook Ads", "Google", "QuickBooks". The seed script to create a google_ads integration with selected accounts failed because the Phoenix server was already running (Cloudflare tunnel conflict prevents `mix run -e` invocations). The existing google integration is stored as provider `:google` (not `:google_ads`), so no card shows "Google Ads" specifically.

Platform names are correctly rendered from the `@platform_metadata` map for all providers returned by `Integrations.list_providers()`.

Screenshot: `.code_my_spec/qa/436/screenshots/integration-platform-name.png`

### Scenario 4: Connected date shown per integration (AC: each integration shows connected date)

pass

`[data-role='integration-connected-date']` is present within `[data-role='integration-row']`. Text reads "Connected 2026-03-11". The date format used is `%Y-%m-%d` (ISO 8601), not the human-readable "Mar 05, 2026" format that the brief anticipated — but the spec does not mandate a specific format and the information is present and readable.

For available (disconnected) platforms, the element shows "Not connected" (italic).

### Scenario 5: Sync status shown per integration (AC: each integration shows sync status)

pass

`[data-role='integration-sync-status']` is present. For connected platforms there is a separate `data-status="connected"` `badge-success` "Connected" badge adjacent to the sync status element. The sync status element itself renders sync results when a sync has completed. In the available platform cards, `[data-role='integration-sync-status']` contains a `badge-ghost` "Not connected" badge.

### Scenario 6: Selected accounts visible per integration (AC: user can see selected ad accounts)

partial

`[data-role='integration-selected-accounts']` elements exist on all integration cards. For the existing test integrations (google, facebook_ads, quickbooks), the element shows "No accounts selected" because no `selected_accounts` were stored in `provider_metadata`. The seed script to create a google_ads integration with `["Campaign Alpha", "Campaign Beta"]` in `provider_metadata` failed due to server conflict. The element structure is correct and renders account lists when data is present.

Screenshot: `.code_my_spec/qa/436/screenshots/integration-selected-accounts.png`

### Scenario 7: Integration detail link present (AC: selected accounts/view detail)

pass

`[data-role='integration-detail-link']` is present on all integration cards, both connected and available. For connected cards it navigates to `/integrations/connect/{provider}` (e.g. `/integrations/connect/google`). For available cards the same link is present. Confirmed href attribute value via `browser_get_attribute`.

### Scenario 8: Edit accounts link present (AC: modify selected accounts without re-authenticating)

pass

`[data-role='edit-integration-accounts']` link is present on connected cards and navigates to `/integrations/connect/{provider}/accounts`. The link does not trigger OAuth redirect — it is a `data-phx-link="redirect"` navigation to the accounts sub-page. Not present on available platform cards (correctly absent since there is no integration to edit accounts for).

### Scenario 9: Disconnect button present and modal opens (AC: disconnect/remove integration)

fail

`[data-role='disconnect-integration']` button is present on connected cards. Clicking it shows an inline warning panel (`[data-role='disconnect-warning']`) — NOT a modal overlay. The brief expected `[class*='modal-open']` (a modal dialog), but the implementation uses an inline collapsible panel within the card.

The panel heading reads "Disconnect Facebook Ads?" — the "Disconnect {platform name}?" pattern is correct.

Screenshot: `.code_my_spec/qa/436/screenshots/disconnect-modal.png`

### Scenario 10: Disconnect warning message shown (AC: disconnecting shows warning about historical data)

pass

After clicking `[data-role='disconnect-integration']`, the `[data-role='disconnect-warning']` element becomes visible. Text reads: "Historical data will remain available, but no new data will sync after disconnecting." This satisfies both expected substrings: "Historical data will remain" and "No new data will sync after disconnecting."

### Scenario 11: Confirm/cancel options in disconnect modal (AC: disconnect warning with confirm/cancel)

fail

`[data-role='confirm-disconnect']` button is present but its label is "Confirm", not "Disconnect" as the brief expected.
`[data-role='cancel-disconnect']` button is present and labeled "Cancel" — matches expected.

Clicking "Cancel" closes the inline warning panel and restores the card to its normal state. Integration remains connected after cancel.

Screenshot: `.code_my_spec/qa/436/screenshots/disconnect-cancelled.png`

### Scenario 12: Confirm disconnect removes integration from connected list (AC: disconnect removes integration)

pass with note

After clicking `[data-role='disconnect-integration']` then `[data-role='confirm-disconnect']`, Facebook Ads was removed from "Connected Platforms". The flash message displayed was: "Disconnected from Facebook Ads. Historical data is retained." — the brief expected the message to include "; no new data will sync after disconnecting." but the actual message ends at "Historical data is retained."

Facebook Ads appeared in the "Available Platforms" section with "Not connected" status and a "Connect" button, as expected.

Screenshot: `.code_my_spec/qa/436/screenshots/integration-disconnected.png`

### Scenario 13: Reconnect option visible for disconnected platform (AC: reconnect previously disconnected platform)

fail

After disconnecting Facebook Ads, `[data-role='reconnect-integration']` button appeared with text "Connect". This matches the expected button label.

However, clicking "Connect" immediately redirected to Facebook's OAuth authorization page (`https://www.facebook.com/login.php?...`). The brief expected a flash message "Reconnect Google Ads: authorize your account on the Connect page." but the implementation dispatches `phx-click="initiate_connect"` which calls `redirect(socket, to: ~p"/integrations/oauth/#{provider_str}")`, starting the OAuth flow directly. No flash message is shown.

Screenshot: `.code_my_spec/qa/436/screenshots/reconnect-button.png`

### Scenario 14: Disconnected vs connected platforms visually distinguishable (AC: reconnect/visual state)

pass

Connected cards: `data-status="connected"` on the card element, `.badge-success` with "Connected" text.
Available cards: `data-status="available"` on the card element, `.badge-ghost` with "Not connected" text, and `[data-role='integration-sync-status']` also renders with `.badge-ghost`.

Visual distinction is clear and correct.

### Scenario 15: Uniform card layout for all integrations including QuickBooks (AC: uniform treatment)

pass

No `[data-role='quickbooks-special-section']` element found anywhere on the page. All cards use `[data-role='integration-card']` with the same structure. QuickBooks card is indistinguishable in layout from Google and Facebook Ads cards.

## Evidence

- `.code_my_spec/qa/436/screenshots/integrations-index.png` — initial page load with three connected platforms
- `.code_my_spec/qa/436/screenshots/integration-platform-name.png` — platform name elements visible
- `.code_my_spec/qa/436/screenshots/integration-selected-accounts.png` — full page showing selected accounts section (showing "No accounts selected" fallback)
- `.code_my_spec/qa/436/screenshots/disconnect-modal.png` — inline warning panel after clicking disconnect
- `.code_my_spec/qa/436/screenshots/disconnect-cancelled.png` — page after cancel, integration still connected
- `.code_my_spec/qa/436/screenshots/integration-disconnected.png` — page after confirming disconnect, Facebook Ads moved to Available Platforms
- `.code_my_spec/qa/436/screenshots/reconnect-button.png` — Available Platforms section with Connect button

## Issues

### Disconnect confirmation uses inline panel, not modal overlay

#### Severity
LOW

#### Description
The disconnect confirmation UI is rendered as an inline panel that expands within the integration card (`[data-role='disconnect-warning']`), not as a modal dialog. The brief and UI spec both describe a `.modal` overlay with `class*='modal-open'`.

The inline panel is functional and provides the warning message and confirm/cancel buttons, but it does not match the spec's "Disconnect confirmation modal" description. The spec's Design section says: "Disconnect confirmation modal (shown when `disconnecting_provider` is set): `.modal` overlay containing...".

Reproduction: Navigate to `/integrations`, click "Disconnect" on any connected card — a panel expands within the card rather than a full-page modal overlay appearing.

### Confirm disconnect button labeled "Confirm" instead of "Disconnect"

#### Severity
LOW

#### Description
The `[data-role='confirm-disconnect']` button inside the disconnect warning panel displays "Confirm" rather than "Disconnect". The spec's Design section says the confirm button should be labeled "Disconnect". Users may expect explicit "Disconnect" text on the final confirmation action.

Reproduction: Click "Disconnect" on a connected card → the warning panel shows a button labeled "Confirm" (not "Disconnect").

### Disconnect flash message missing "no new data will sync" clause

#### Severity
LOW

#### Description
After confirming disconnect, the flash message reads: "Disconnected from {Platform}. Historical data is retained."

The spec and brief both indicate the message should include the additional clause: "no new data will sync after disconnecting." or equivalent. The current message omits this information.

Source location: `lib/metric_flow_web/live/integration_live/index.ex` in the `handle_event("disconnect", ...)` handler, `put_flash(:info, "Disconnected from #{name}. Historical data is retained.")`.

### Connect button initiates OAuth instead of showing informational flash

#### Severity
INFO

#### Description
In the Available Platforms section, clicking the "Connect" button (`[data-role='reconnect-integration']`) immediately redirects the user to the OAuth provider (e.g. Facebook's login page). The brief expected a flash message like "Reconnect {Platform}: authorize your account on the Connect page." but no flash is shown.

The behavior (direct OAuth redirect) is not necessarily wrong from a UX standpoint — it gets the user to auth faster — but it differs from the brief's expected behavior. If the intent is to show a flash and keep the user on the integrations page first, the `handle_event("initiate_connect", ...)` handler needs to be changed.

### google_ads integration seed cannot be run while server is active

#### Severity
MEDIUM

#### Scope
QA

#### Description
The brief instructs running a `mix run -e '...'` one-liner to create a google_ads integration with `selected_accounts` in `provider_metadata`. This fails when the Phoenix server is already running because the Cloudflare tunnel GenServer conflicts with the `mix run` process attempting to start the application.

The brief acknowledges this is a "one-off seed step" but does not provide an alternative for the server-running scenario. As a result, the selected_accounts scenario (Scenario 6) and the "Google Ads" platform name scenarios could not be tested with the intended seed data.

Resolution options: (1) Add a `--no-start` compatible version of the seed using `Repo.start_link` and skipping Cloudflare, (2) Add the google_ads integration to `priv/repo/qa_seeds.exs` as an idempotent step, or (3) Use a Mix task that bypasses the full application startup.
