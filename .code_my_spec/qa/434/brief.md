# QA Story Brief

Story 434: Connect Marketing Platform via OAuth

## Tool

web (vibium MCP browser tools — `IntegrationLive.Connect` is a LiveView)

## Auth

Run seeds first, then launch the browser and log in via the password form:

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

Run the base QA seed script before testing. It is idempotent.

```bash
cd /Users/johndavenport/Documents/github/metric_flow && mix run priv/repo/qa_seeds.exs
```

No additional story-specific seeds are needed. The seed creates a QA owner user with no pre-existing integrations, which matches the expected pre-OAuth state for this story.

## What To Test

### Scenario 1 — Platform selection page lists all supported platforms (AC: User can initiate OAuth flow for supported platforms)

- Navigate to `http://localhost:4070/integrations/connect`
- Verify the page renders without error
- Verify "Google Ads" appears on the page
- Verify "Facebook Ads" appears on the page
- Verify "Google Analytics" appears on the page
- Verify each platform card has a `data-platform` attribute (`data-platform="google_ads"`, `data-platform="facebook_ads"`, `data-platform="google_analytics"`)
- Verify each platform card contains an element with `data-role="connect-button"`
- Take a screenshot of the platform selection page

### Scenario 2 — Connect buttons are present for each platform (AC: User can initiate OAuth flow)

- On the platform selection grid at `/integrations/connect`
- Confirm there is a `[data-platform='google_ads'] [data-role='connect-button']` element
- Confirm there is a `[data-platform='facebook_ads'] [data-role='connect-button']` element
- Confirm there is a `[data-platform='google_analytics'] [data-role='connect-button']` element
- Confirm no "Re-authenticate" text is present on the page

### Scenario 3 — Per-platform detail view shows OAuth initiation link (AC: OAuth flow opens in new tab)

- Navigate to `http://localhost:4070/integrations/connect/google_ads`
- Verify the page renders the Google Ads detail card
- Verify an element with `data-role="oauth-connect-button"` is present
- Verify that element has `target="_blank"` (opens in a new tab)
- Verify the element has an `href` attribute pointing to an OAuth authorization URL
- Take a screenshot of the Google Ads detail page

### Scenario 4 — Platform detail view does not show re-authenticate option (AC: User can modify selected accounts without re-authenticating)

- On `http://localhost:4070/integrations/connect/google_ads`
- Verify "Re-authenticate" does not appear on the page
- Verify "Re-connect" does not appear on the page
- Verify the page shows "account" or "Connect" or "Google Ads" content (confirming it loaded)

### Scenario 5 — Account selection page renders correctly (AC: User can select which ad accounts or properties to sync)

- Navigate to `http://localhost:4070/integrations/connect/google_ads/accounts`
- Verify the page renders the account selection view
- Verify `[data-role='account-list']` is present
- Verify `[data-role='account-selection']` is present
- Verify `input[type='checkbox'][data-role='account-checkbox']` is present
- Verify `[data-role='save-selection']` button labeled "Save Selection" is present
- Take a screenshot of the account selection page

- Repeat for `http://localhost:4070/integrations/connect/google_analytics/accounts`
- Verify the Google Analytics accounts page renders a similar account/property selection UI

### Scenario 6 — Integration not saved before OAuth (AC: Integration is saved only after successful OAuth completion)

- Navigate to `http://localhost:4070/integrations/connect/google_ads`
- Verify "Integration saved" does not appear on the page
- Verify "Integration active" does not appear on the page
- Verify the page does show a connect/authorize option (`data-role="oauth-connect-button"` or a connect button)

### Scenario 7 — OAuth callback success state shows confirmation (AC: User sees confirmation integration is active and ready to sync)

- Navigate to `http://localhost:4070/integrations/oauth/callback/google_ads?code=test_auth_code&state=test_state`
- Wait for the page to settle (`mcp__vibium__browser_wait_for_load`)
- Inspect the rendered page content
- The OAuth token exchange will likely fail (no real provider configured), so look for either:
  - Success path: "Integration Active", "Active" badge, "connected and ready to sync" text, "View Integrations" button
  - Error path (acceptable if provider not configured): "Connection Failed" heading, "Try again" link, "Back to integrations" link
- Verify the page does NOT show "Integration saved" or "successfully connected" if in error state
- Take a screenshot of the callback result page

### Scenario 8 — OAuth callback with error parameter shows clear error message (AC: Failed OAuth attempts show clear error messages)

- Navigate to `http://localhost:4070/integrations/oauth/callback/google_ads?error=access_denied`
- Wait for the page to load
- Verify "Connection Failed" heading is visible
- Verify error-related text appears (e.g., "Access was denied", "error", "denied", "failed")
- Verify "Integration saved" and "successfully connected" do NOT appear
- Verify a "Try again" link is present pointing back to `/integrations/connect/google_ads`
- Verify a "Back to integrations" link is present
- Take a screenshot

- Navigate to `http://localhost:4070/integrations/oauth/callback/google_ads?error=access_denied&error_description=User+denied+access`
- Verify the page renders an error state with actionable recovery links

### Scenario 9 — Unauthenticated user is redirected (AC: Platform connection belongs to client account)

- Clear cookies to simulate a logged-out user
- Attempt to navigate to `http://localhost:4070/integrations/connect`
- Verify the user is redirected to the login page (URL should contain `/users/log-in`)

### Scenario 10 — Integration page is scoped to the logged-in account (AC: Platform connection belongs to client account and is not transferable to agency)

- Log in as `qa@example.com`
- Navigate to `http://localhost:4070/integrations`
- Verify the page renders the integrations list for this user's account
- Verify no "Transfer to agency", "Assign to agency", or "Move to agency" text appears
- Navigate to `http://localhost:4070/integrations/connect/google_ads`
- Confirm none of those transfer phrases appear on the detail page either
- Take a screenshot of the integrations page

## Result Path

`.code_my_spec/qa/434/result.md`

## Setup Notes

The OAuth callback route (`/integrations/oauth/callback/:provider`) is a LiveView route, not a controller action. Visiting it in the browser with `?code=...&state=...` will trigger `handle_params/3` with the `:callback` live action, which calls `Integrations.handle_callback/4`. In a test environment without real provider credentials configured, this call will return an error — the callback view will render the error state. This is expected behavior. Test that the error state renders correctly with the "Connection Failed" UI rather than expecting a successful connection.

The OAuth "connect" button on the platform selection page (`phx-click="connect"`) triggers a server-side redirect to the provider authorization URL. Clicking it in a browser session will attempt to redirect to Google/Facebook. Do NOT click the connect button during testing — verify its presence and attributes only. Instead, test the callback result states by navigating directly to the callback URL with simulated parameters.
