# QA Story Brief

Story 435 — Connect Financial Platform via OAuth. Tests the `IntegrationLive.Connect` LiveView for platform discovery, OAuth initiation, account selection, callback handling (success and error paths), and confirmation UI.

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind `:require_authenticated_user`)

## Auth

Run seeds, then log in via the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

Credentials: `qa@example.com` / `hello world!`

## Seeds

Run the base QA seeds before testing. No story-specific seeds are required — the test creates no integration records prior to testing.

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

Expected output includes:
```
Owner:    qa@example.com / hello world!
URL:      http://localhost:4070/users/log-in
```

## Setup Notes

QuickBooks is NOT a configured OAuth provider in this application. The `@default_providers` map in `MetricFlow.Integrations` contains only `google`. The canonical platform grid in `IntegrationLive.Connect` lists `google_ads`, `facebook_ads`, `google_analytics`, and `unsupported_platform` — QuickBooks is absent.

The BDD specs expect QuickBooks to appear as a connectable platform and for the OAuth callback to succeed with a `code` parameter. These tests exercise whether the story has been implemented. Testing against the live app will reveal what is and isn't in place.

For the error-path scenarios (access_denied, missing code, server_error), no real OAuth provider is needed — navigate directly to `/integrations/oauth/callback/quickbooks?error=access_denied` and similar URLs. The LiveView handles error params independently of the provider being configured.

The `unsupported_platform` card IS shown in the grid — clicking its Connect button should produce a flash error "This platform is not yet supported".

## What To Test

### Scenario 1 — Platform selection page loads and shows the platform grid (AC: User can initiate OAuth flow for QuickBooks)

- Navigate to `http://localhost:4070/integrations/connect`
- Take a screenshot
- Verify the page renders with the heading "Connect a Platform"
- Verify the subtitle "Link your marketing accounts to start syncing data" is visible
- Check whether a card with `data-platform="quickbooks"` is present in the DOM
- Check whether "Google Ads", "Facebook Ads", "Google Analytics" cards are present
- Check that each visible platform card has a "Not connected" badge and a Connect button (`[data-role='connect-button']`)

Expected: Platform grid renders. QuickBooks card presence/absence is a key finding.

### Scenario 2 — Clicking Connect on an unsupported platform shows an error flash (AC: Failed OAuth attempts show clear error messages)

- On the `/integrations/connect` page, find the `[data-platform='unsupported_platform']` card
- Click its `[data-role='connect-button']`
- Wait for the flash message to appear
- Verify the flash contains "This platform is not yet supported"
- Take a screenshot

Expected: Error flash appears, user stays on the connect page.

### Scenario 3 — Clicking Connect on a supported platform initiates OAuth redirect (AC: User can initiate OAuth flow for QuickBooks)

- On `/integrations/connect`, find a platform card for a configured provider (google_ads or whatever is present)
- Click its Connect button
- Observe behavior — expect a redirect to an external OAuth URL, OR if the provider is not configured, an error flash

This scenario validates the OAuth initiation path. Document what actually happens.

### Scenario 4 — Per-platform detail page renders (AC: User can initiate OAuth flow for QuickBooks)

- Navigate to `http://localhost:4070/integrations/connect/google_ads`
- Take a screenshot
- Verify the page shows a platform name heading
- Verify a "Not connected" badge is shown (no existing integration)
- Check whether `[data-role='oauth-connect-button']` is present (requires a configured provider with an authorize URL)
- Check whether `[data-role='account-selection']` section is present
- Verify a "Back to integrations" link is present

### Scenario 5 — QuickBooks detail page (AC: Financial data becomes just another metric)

- Navigate to `http://localhost:4070/integrations/connect/quickbooks`
- Take a screenshot
- Document what the page shows — either a QuickBooks-specific detail view or a redirect/error
- If the page renders, verify it mentions QuickBooks and has a sync data description

Expected outcome depends on whether QuickBooks is implemented.

### Scenario 6 — Account selection page (AC: After successful authentication, user can select which income accounts)

- Navigate to `http://localhost:4070/integrations/connect/quickbooks/accounts`
- Take a screenshot
- Verify the page has `[data-role='account-selection']` element
- Verify the page has `[data-role='account-checkbox']` element(s)
- Verify the page has `[data-role='account-list']` element
- Verify the page title or heading references QuickBooks
- Verify a "Save Selection" button (`[data-role='save-selection']`) is present

### Scenario 7 — Saving account selection redirects to integrations (AC: User can select multiple income accounts)

- On the account selection page (`/integrations/connect/quickbooks/accounts`), click the "Save Selection" button (`[data-role='save-selection']`)
- Verify the browser redirects to `/integrations`
- Take a screenshot of the integrations list page

Expected: Redirect to `/integrations` after saving.

### Scenario 8 — OAuth callback with access_denied error (AC: Failed OAuth attempts show clear error messages)

- Navigate to `http://localhost:4070/integrations/oauth/callback/quickbooks?error=access_denied`
- Take a screenshot
- Verify the page shows the heading "Connection Failed"
- Verify the page contains the text "denied" (from "Access was denied")
- Verify a "Try again" link is present
- Verify a "Back to integrations" link is present
- Verify no "Active" badge is shown

### Scenario 9 — OAuth callback with server_error and description (AC: Failed OAuth attempts show clear error messages)

- Navigate to `http://localhost:4070/integrations/oauth/callback/quickbooks?error=server_error&error_description=Something+went+wrong`
- Take a screenshot
- Verify the page shows "Connection Failed"
- Verify the page contains "server_error" or "Something went wrong"
- Verify the page indicates the account is "not active" or shows "Failed"

### Scenario 10 — OAuth callback with no parameters (AC: Failed OAuth attempts show clear error messages)

- Navigate to `http://localhost:4070/integrations/oauth/callback/quickbooks`
- Take a screenshot
- Verify the page shows an error state — "No authorization code" or "Connection Failed"

### Scenario 11 — OAuth callback with a valid code (success path) (AC: Integration is saved only after successful OAuth completion; User sees confirmation that QuickBooks is connected)

- Navigate to `http://localhost:4070/integrations/oauth/callback/quickbooks?code=test_auth_code`
- Take a screenshot
- Observe whether the page shows:
  - "Integration Active" heading
  - A reference to QuickBooks by name
  - "ready to sync" or "connected and ready" text
  - An "Active" badge (`badge-success`)
  - "View Integrations" and "Connect another platform" links
- If the callback fails (because quickbooks is not a configured provider), document the error shown

Note: This scenario will likely fail or show an error because `quickbooks` is not in the provider map. The behavior under that condition (error message shown to user) is the finding.

### Scenario 12 — Integrations list does not show QuickBooks as connected before OAuth (AC: Integration is saved only after successful OAuth completion)

- Before running any successful OAuth callback, navigate to `http://localhost:4070/integrations`
- Take a screenshot
- Verify QuickBooks is NOT shown as "Connected" in the list

### Scenario 13 — Connect page shows QuickBooks alongside other marketing platforms (AC: Financial data becomes just another metric)

- Navigate to `http://localhost:4070/integrations/connect`
- Check whether "QuickBooks" text appears in the platform grid
- Check whether "Google Ads" or "Facebook Ads" also appears
- This verifies QuickBooks is treated as a peer platform alongside marketing tools

## Result Path

`.code_my_spec/qa/435/result.md`
