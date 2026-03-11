# Qa Result

## Status

partial

## Scenarios

### Scenario 1 — Platform selection page loads and shows platform grid

pass

Navigated to `http://localhost:4070/integrations/connect`. The page loaded with heading "Connect a Platform" and subtitle "Link your marketing accounts to start syncing data". The platform grid rendered with 5 cards: Facebook Ads, Google, Google Ads, Google Analytics, and Unsupported Platform. Each card has a `data-platform` attribute, a connection status badge, and a `[data-role='connect-button']` button.

Key finding: QuickBooks is NOT present in the platform grid at `/integrations/connect`. The `@canonical_platforms` list in `Connect.ex` includes `google_ads`, `facebook_ads`, `google_analytics`, and `unsupported_platform` — but not `quickbooks`. QuickBooks does appear in the `/integrations` (index) page under "Available Platforms", but not on the connect flow's selection grid.

Google Ads and Google show as "Connected" with a "Reconnect" button — this reflects existing integration data seeded from a prior session.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-01-platform-selection.png`

### Scenario 2 — Clicking Connect on unsupported platform shows flash error

pass

Clicked the `[data-role='connect-button']` on `[data-platform='unsupported_platform']`. A flash message appeared at the bottom of the page: "This platform is not yet supported". The user remained on `/integrations/connect`. The flash behavior matches the spec.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-02-unsupported-flash.png`

### Scenario 3 — Clicking Connect on a supported platform initiates OAuth redirect

fail

Clicked the Connect button on Facebook Ads (`[data-platform='facebook_ads']`) — got flash "This platform is not yet supported". Facebook Ads is listed in `@canonical_platforms` but has no configured OAuth provider module, so `authorize_url(:facebook_ads)` returns `{:error, :unsupported_provider}`.

Clicked the Reconnect button on Google Ads (`[data-platform='google_ads']`) — also got flash "This platform is not yet supported". Despite showing "Connected" in the grid, clicking Reconnect fails with the same error. This is a mismatch: Google Ads is shown as Connected (because a `google_ads` integration exists from seeded data), but its provider is not configured for OAuth initiation.

The only working OAuth provider is `google` — navigating to `/integrations/connect/google` shows a real OAuth authorize URL pointing to `accounts.google.com`.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-03-facebook-connect.png`, `.code_my_spec/qa/435/screenshots/scenario-03-google-ads-reconnect.png`, `.code_my_spec/qa/435/screenshots/explore-google-detail.png`

### Scenario 4 — Per-platform detail page renders (google_ads)

pass (partial)

Navigated to `http://localhost:4070/integrations/connect/google_ads`. The page rendered with:
- Heading "Google Ads" (platform name)
- "Connected" badge (integration exists from seeded data) with "Connected as qa@example.com"
- `[data-role='account-selection']` section present
- "Back to integrations" link present

`[data-role='oauth-connect-button']` was NOT present (expected, since `authorize_url(:google_ads)` fails and the template only shows the OAuth button when `@authorize_url` is non-nil).

Evidence: `.code_my_spec/qa/435/screenshots/scenario-04-google-ads-detail.png`

### Scenario 5 — QuickBooks detail page

pass

Navigated to `http://localhost:4070/integrations/connect/quickbooks`. The page rendered without redirecting — it shows a detail view for "Quickbooks" (capitalization derived from `derive_display_name/1`). The page shows:
- Heading "Quickbooks" (not "QuickBooks" — derived via `String.capitalize/1`)
- "Not connected" badge
- "Connect your Quickbooks account to begin syncing data." description
- A "Connect Quickbooks" phx-click button (not an OAuth anchor, since no authorize URL exists)
- "Back to integrations" link

The page does not show a QuickBooks-specific sync data description as expected by the acceptance criterion "Financial data becomes just another metric" — it uses the generic fallback description.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-05-quickbooks-detail.png`

### Scenario 6 — Account selection page

pass

Navigated to `http://localhost:4070/integrations/connect/quickbooks/accounts`. The page rendered with:
- `[data-role='account-selection']` present
- `[data-role='account-checkbox']` present (checked "All accounts" checkbox)
- `[data-role='account-list']` present
- Heading "Quickbooks — Select Accounts"
- `[data-role='save-selection']` "Save Selection" button present

Evidence: `.code_my_spec/qa/435/screenshots/scenario-06-account-selection.png`

### Scenario 7 — Saving account selection redirects to integrations

pass

Clicked `[data-role='save-selection']` on the account selection page. Browser redirected to `http://localhost:4070/integrations` as expected.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-07-save-redirects-integrations.png`

### Scenario 8 — OAuth callback with access_denied error

pass

Navigated to `http://localhost:4070/integrations/oauth/callback/quickbooks?error=access_denied`. The page showed:
- Heading "Connection Failed"
- Provider name "Quickbooks"
- Error message "Access was denied" (contains "denied")
- "Try again" link
- "Back to integrations" link
- No "Active" badge (`.badge-success` not visible)

Evidence: `.code_my_spec/qa/435/screenshots/scenario-08-access-denied.png`

### Scenario 9 — OAuth callback with server_error and description

pass

Navigated to `http://localhost:4070/integrations/oauth/callback/quickbooks?error=server_error&error_description=Something+went+wrong`. The page showed:
- "Connection Failed" heading
- Error message "Authorization failed: server_error — Something went wrong" (contains both `server_error` and "Something went wrong")
- "Your Quickbooks account is not active — connection could not be established." (not active message)
- "Try again" and "Back to integrations" links

Evidence: `.code_my_spec/qa/435/screenshots/scenario-09-server-error.png`

### Scenario 10 — OAuth callback with no parameters

pass

Navigated to `http://localhost:4070/integrations/oauth/callback/quickbooks`. The page showed "Connection Failed" with error message "No authorization code received."

Evidence: `.code_my_spec/qa/435/screenshots/scenario-10-no-params.png`

### Scenario 11 — OAuth callback with valid code (success path)

fail

Navigated to `http://localhost:4070/integrations/oauth/callback/quickbooks?code=test_auth_code`. The page showed "Connection Failed" with message "Could not complete the connection. Please try again." — not "Integration Active". This is expected behavior for an unsupported provider: `Integrations.handle_callback` was called (the `quickbooks` atom exists in the VM from earlier navigation) but returned an error, resulting in the failure state.

No "Integration Active" heading, no "Active" badge, no "View Integrations" link. The success path for QuickBooks is not implemented.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-11-valid-code.png`

### Scenario 12 — Integrations list does not show QuickBooks as connected

pass

Navigated to `http://localhost:4070/integrations`. QuickBooks appeared under "Available Platforms" with status "Not connected". It was NOT shown as "Connected" in the "Connected Platforms" section. The connected platforms showed only Google and Google Ads.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-12-integrations-list.png`

### Scenario 13 — Connect page shows QuickBooks alongside marketing platforms

fail

Navigated to `http://localhost:4070/integrations/connect`. QuickBooks was NOT visible in the platform grid. The grid showed: Facebook Ads, Google, Google Ads, Google Analytics, and Unsupported Platform. "Google Ads" and "Facebook Ads" were present, but QuickBooks was absent.

The acceptance criterion "Financial data becomes just another metric" requires QuickBooks to appear as a peer platform alongside marketing tools in the connect grid. This is not implemented.

Evidence: `.code_my_spec/qa/435/screenshots/scenario-13-connect-page-no-quickbooks.png`

## Evidence

- `.code_my_spec/qa/435/screenshots/login-page.png` — Login page showing email pre-filled from prior session
- `.code_my_spec/qa/435/screenshots/scenario-01-platform-selection.png` — Platform selection grid (no QuickBooks card)
- `.code_my_spec/qa/435/screenshots/scenario-02-unsupported-flash.png` — "This platform is not yet supported" flash after clicking unsupported platform
- `.code_my_spec/qa/435/screenshots/scenario-03-facebook-connect.png` — Facebook Ads connect shows "not yet supported" error
- `.code_my_spec/qa/435/screenshots/scenario-03-google-ads-reconnect.png` — Google Ads reconnect shows "not yet supported" error despite "Connected" badge
- `.code_my_spec/qa/435/screenshots/explore-google-detail.png` — Google provider detail page with real OAuth authorize URL
- `.code_my_spec/qa/435/screenshots/scenario-04-google-ads-detail.png` — Google Ads detail page (connected, no OAuth button)
- `.code_my_spec/qa/435/screenshots/scenario-05-quickbooks-detail.png` — QuickBooks detail page (rendered via fallback, not QuickBooks-specific)
- `.code_my_spec/qa/435/screenshots/scenario-06-account-selection.png` — Account selection page with all required data-role elements
- `.code_my_spec/qa/435/screenshots/scenario-07-save-redirects-integrations.png` — Integrations list after saving account selection
- `.code_my_spec/qa/435/screenshots/scenario-08-access-denied.png` — OAuth callback error: access_denied
- `.code_my_spec/qa/435/screenshots/scenario-09-server-error.png` — OAuth callback error: server_error with description
- `.code_my_spec/qa/435/screenshots/scenario-10-no-params.png` — OAuth callback with no parameters shows "No authorization code received"
- `.code_my_spec/qa/435/screenshots/scenario-11-valid-code.png` — OAuth callback with code fails for quickbooks (unsupported provider)
- `.code_my_spec/qa/435/screenshots/scenario-12-integrations-list.png` — Integrations list showing QuickBooks as "Not connected" under Available Platforms
- `.code_my_spec/qa/435/screenshots/scenario-13-connect-page-no-quickbooks.png` — Connect grid without QuickBooks

## Issues

### QuickBooks is absent from the /integrations/connect platform grid

#### Severity
HIGH

#### Description
The `/integrations/connect` platform selection grid does not include a QuickBooks card. The `@canonical_platforms` list in `MetricFlowWeb.IntegrationLive.Connect` contains only `google_ads`, `facebook_ads`, `google_analytics`, and `unsupported_platform`. QuickBooks is not present.

The acceptance criteria for story 435 require that a client user can "connect my QuickBooks account" and that "Financial data becomes just another metric" — both require QuickBooks to appear as a connectable platform in the connect grid.

QuickBooks does appear in the `/integrations` (index) page's "Available Platforms" section, but this page does not serve the connection initiation flow.

To fix: add a QuickBooks entry to `@canonical_platforms` and `@platform_metadata` in `connect.ex`, and configure a QuickBooks OAuth provider in `MetricFlow.Integrations`.

### Google Ads card shows "Connected" but Connect/Reconnect button shows unsupported error

#### Severity
MEDIUM

#### Description
On the `/integrations/connect` grid, the Google Ads card shows a "Connected" badge and a "Reconnect" button. Clicking "Reconnect" shows the flash "This platform is not yet supported" — because `google_ads` has no configured OAuth provider module, only `google` does.

This creates a misleading UI: a user who has a Google Ads integration (seeded or otherwise) sees it as "Connected" but cannot reconnect it through the OAuth flow. The `authorize_url(:google_ads)` call returns `{:error, :unsupported_provider}`.

Reproduced at: `http://localhost:4070/integrations/connect` — click Reconnect on the Google Ads card.

### QuickBooks display name uses incorrect capitalization

#### Severity
LOW

#### Description
When navigating to `/integrations/connect/quickbooks` or `/integrations/oauth/callback/quickbooks`, the provider display name is shown as "Quickbooks" (lowercase 'b') instead of "QuickBooks" (capital B). This is because the `derive_display_name/1` function applies `String.capitalize/1` to each word, which lowercases all letters after the first.

This applies everywhere `provider_display_name("quickbooks")` is called, including the callback error page and detail view.

Reproduced at: `http://localhost:4070/integrations/connect/quickbooks`

### QuickBooks OAuth success path not implemented

#### Severity
HIGH

#### Description
Navigating to `/integrations/oauth/callback/quickbooks?code=test_auth_code` shows "Connection Failed" with "Could not complete the connection. Please try again." — the success path for QuickBooks OAuth is not implemented. The `Integrations.handle_callback` function cannot exchange a QuickBooks authorization code because no QuickBooks OAuth provider is configured.

The acceptance criteria require: "Integration is saved only after successful OAuth completion" and "User sees confirmation that QuickBooks is connected." Neither is achievable in the current state.

Reproduced at: `http://localhost:4070/integrations/oauth/callback/quickbooks?code=test_auth_code`

### Seed script fails when run via `mix run` due to Cloudflare tunnel permission

#### Severity
MEDIUM

#### Scope
QA

#### Description
Running `mix run priv/repo/qa_seeds.exs` fails with:

```
(File.Error) could not write to file "/Users/johndavenport/.cloudflared/config.yml": not owner
```

The `ClientUtils.CloudflareTunnel` GenServer attempts to write its config file on startup. In the sandbox environment, the QA agent lacks permission to write to `~/.cloudflared/`. The full application start is required for `mix run`, which triggers the CloudflareTunnel supervisor.

The QA session proceeded without running seeds because the `qa@example.com` user already existed from a prior session (the seed script is idempotent and was previously run successfully).

To fix: the seed script or the QA plan should document how to run seeds in environments where the Cloudflare tunnel config is not writable. A possible workaround is to configure `MIX_ENV=test mix run priv/repo/qa_seeds.exs` if the test environment disables the tunnel, or to add a Mix task that runs seeds without booting the full application supervisor.
