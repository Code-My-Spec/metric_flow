# QA Result

Story 436: View and Manage Platform Integrations

## Status

fail

## Scenarios

### Scenario 1: Unauthenticated redirect

pass

Ran `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations` without auth cookies.
Result: HTTP 302. The route is correctly protected and redirects unauthenticated users.

### Scenario 2: Page loads with integration list heading

pass (partial)

Navigated to `http://localhost:4070/integrations` while logged in as `qa@example.com`. The page loaded
successfully with no redirect. An `<h1>` element containing "Integrations" is present. The
"Connected Platforms" and "Available Platforms" headings are also rendered.

However: the "Connected Platforms" section shows the heading but renders no integration cards, despite a
`google_ads` integration record existing in the database for the user. See Issue: Connected integration
card not rendered.

Screenshot: `.code_my_spec/qa/436/screenshots/01-integrations-index.png`

### Scenario 3: Marketing platform name visible

fail

No `[data-role='integration-platform-name']` element found on the page. No connected integration card is
rendered at all. The seeded `google_ads` integration does not appear in the Connected Platforms section.
The canonical platforms (Google Ads, Facebook Ads, Google Analytics) also do not appear in the
Available Platforms section — only "Google" is shown.

### Scenario 4: Connected date shown per integration

fail

No `[data-role='integration-connected-date']` element found. No connected card is rendered.

### Scenario 5: Sync status shown per integration

fail

No `[data-role='integration-sync-status']` element found. No connected card is rendered.

### Scenario 6: Selected accounts visible per integration

fail

No `[data-role='integration-selected-accounts']` element found. The seed data includes
`"selected_accounts" => ["Campaign Alpha", "Campaign Beta"]` in `provider_metadata`, but no card is
rendered to display them.

### Scenario 7: Integration detail link present

fail

No `[data-role='integration-detail-link']` element found. No connected card is rendered.

### Scenario 8: Edit accounts link present

fail

No `[data-role='edit-integration-accounts']` element found. No connected card is rendered.

### Scenario 9: Disconnect button present and modal opens

fail

No `[data-role='disconnect-integration']` button found. No connected card is rendered.

### Scenario 10: Disconnect warning message shown

fail

Cannot test — disconnect button not present. No connected card rendered.

### Scenario 11: Confirm/cancel options in disconnect modal

fail

Cannot test — disconnect button not present. No connected card rendered.

### Scenario 12: Confirm disconnect removes integration from connected list

fail

Cannot test — disconnect button not present. No connected card rendered.

### Scenario 13: Reconnect option visible for disconnected platform

partial

A `[data-role='reconnect-integration']` button is present on the "Google" card in Available Platforms.
Clicking the button triggers a flash message: "Reconnect Google: authorize your account on the Connect
page." This matches the `handle_event("reconnect", ...)` implementation. However, the canonical
platforms (Google Ads, Facebook Ads, Google Analytics) do not appear in Available Platforms — only
Google is listed. The reconnect feature for google_ads cannot be tested.

Screenshot: `.code_my_spec/qa/436/screenshots/03-reconnect-flash.png`

### Scenario 14: Disconnected vs connected platforms visually distinguishable

partial

The Google card in Available Platforms correctly shows `badge-ghost` with "Not connected" text and
`data-status="available"`. Connected platform cards with `badge-success` and `data-status="connected"`
cannot be verified because no connected card renders.

### Scenario 15: Uniform card layout — no special QuickBooks UI

pass

No `[data-role='quickbooks-special-section']` element found. No QuickBooks-specific markup exists on the
page. All visible cards share `[data-role='integration-card']`. The acceptance criterion is satisfied
for the rendered content.

## Evidence

- `.code_my_spec/qa/436/screenshots/00-login-page.png` — Login page on initial load (email pre-filled as readonly)
- `.code_my_spec/qa/436/screenshots/01-integrations-index.png` — Full-page integrations index showing only Google in Available Platforms; Connected Platforms heading visible but empty
- `.code_my_spec/qa/436/screenshots/02-connected-platforms-empty.png` — Close-up of Connected Platforms section with no cards despite seeded integration
- `.code_my_spec/qa/436/screenshots/03-reconnect-flash.png` — Flash message after clicking Connect on Google card
- `.code_my_spec/qa/436/screenshots/04-final-state.png` — Final page state; Available Platforms shows only Google

## Issues

### Connected integration card not rendered despite seeded integration

#### Severity
HIGH

#### Description
The "Connected Platforms" section renders the heading but no integration card, even though a
`google_ads` integration record exists in the database for `qa@example.com` (id=1, user_id=2).

Root cause: The running Phoenix server is executing a stale in-memory version of
`MetricFlowWeb.IntegrationLive.Index`. The currently live module's `build_platform_list/0` only calls
`Integrations.list_providers()` (which returns `[:google]`) and does NOT merge the `@canonical_platforms`
list. The updated source file on disk adds `@canonical_platforms` and a union step, but this change was
not loaded into the running server process.

The `data-phx-loc` annotations in the rendered HTML point to the new source line numbers, which
suggests the beam was recompiled from the updated source but hot-reload did not propagate the module
attribute change into the running VM — this typically requires a full server restart.

As a result:
- `@platforms` in the LiveView assign is `[%{key: :google, ...}]` only
- The `google_ads` integration exists in the database and is returned by `Integrations.list_integrations/1`
- `find_integration(@integrations, :google_ads)` would return the integration IF `:google_ads` were in
  `@platforms`, but it isn't
- The Connected Platforms loop renders nothing
- Available Platforms shows only Google (not Google Ads, Facebook Ads, Google Analytics)

Reproduction: Start the Phoenix server, navigate to `/integrations` while logged in as a user with a
`google_ads` integration. Observed on http://localhost:4070/integrations.

Fix: Restart the Phoenix server so the updated `IntegrationLive.Index` module (with `@canonical_platforms`)
is loaded fresh. All connected-card scenarios are expected to pass after restart.

### Canonical platforms missing from Available Platforms section

#### Severity
MEDIUM

#### Description
Google Ads, Facebook Ads, and Google Analytics do not appear in the "Available Platforms" section.
Only "Google (Google OAuth)" is listed. A user has no way to connect these three canonical marketing
platforms from the integrations index page.

This is a direct consequence of the platform list construction bug described above. The `@canonical_platforms`
module attribute (which hardcodes these three platforms) is absent from the running module version.

### QA environment requires server restart to pick up new module code

#### Severity
MEDIUM

#### Scope
QA

#### Description
The running Phoenix development server does not automatically pick up module attribute (`@canonical_platforms`)
changes via hot reload. The beam file on disk is compiled from the updated source, but the in-memory
module in the running BEAM still uses the old `build_platform_list/0` logic.

The QA seed instructions (brief.md) assumed the server is running the current source. The brief should
include a note that the server must be restarted (`mix phx.server`) after significant source changes
before executing browser-based tests. Integration tests that depend on `@canonical_platforms` will fail
until the server is restarted.

Steps to reproduce: Modify a module attribute in a LiveView, recompile (e.g., via `mix compile`), then
navigate to the LiveView in the browser without restarting the server. The module attribute value from
before the change is still used.
