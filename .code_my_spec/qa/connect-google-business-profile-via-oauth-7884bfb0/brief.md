# QA Story Brief

Story 519: Connect Google Business Profile via OAuth

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind `:require_authenticated_user`)

## Auth

Log in as the QA owner user via the password form:

```
mcp__vibium__browser_launch(headless: false)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

## Seeds

The base QA seeds create `qa@example.com` with the "QA Test Account". The user should already have a `google_business` integration from a prior OAuth flow. Verify by navigating to `/integrations` and checking for a "Google Business" entry with "Connected" badge.

If no google_business integration exists, the tester must do a real OAuth flow:
1. Navigate to `/integrations/connect`
2. Click "Connect" on the Google Business card
3. Complete Google OAuth in the browser
4. Return to the app — integration should be created

## What To Test

### Scenario 1: Google Business appears on the connect page

- Navigate to `http://localhost:4070/integrations/connect`
- Expected: Google Business card visible in the provider grid with name and description
- Verify `[data-platform='google_business']` element exists
- Verify the card has a connect/reconnect button
- Screenshot: `01-connect-grid-gbp.png`

### Scenario 2: Google Business detail page

- Navigate to `http://localhost:4070/integrations/connect/google_business`
- Expected: detail page showing "Google Business" heading
- If connected: shows "Connected" badge, email, and "Select Accounts" button
- If not connected: shows connect button to initiate OAuth
- Verify no "Re-authenticate" text (users should not need to re-auth to manage accounts)
- Screenshot: `02-gbp-detail-page.png`

### Scenario 3: OAuth flow initiates correctly

- On the detail page, if a "Connect" or "Reconnect" button exists with `[data-role='oauth-connect-button']`, click it
- Expected: redirected to Google OAuth consent screen (URL contains `accounts.google.com`)
- Note: if already connected, the "Select Accounts" button goes to account selection instead
- Screenshot: `03-oauth-initiate.png` (or note that OAuth was already completed)

### Scenario 4: Account/location selection page with real data

- Navigate to `http://localhost:4070/integrations/connect/google_business/accounts`
- Expected: "Google Business — Select Accounts" heading
- Expected: real location list rendered (NOT the manual entry fallback)
- Verify `[data-role='account-list']` is present
- Verify checkboxes (`input[type='checkbox'][name='location_ids[]']`) for multi-select
- Verify each location row has `[data-role='location-title']` and `[data-role='location-account-name']`
- Verify addresses shown where available (`[data-role='location-address']`)
- Screenshot: `04-location-list.png`

### Scenario 5: Multi-select and save

- On the accounts page, check two or more locations
- Click "Save Selection" (`[data-role='save-selection']`)
- Expected: success flash with count (e.g. "2 location(s) saved successfully.")
- Expected: redirect to `/integrations/connect/google_business` detail page
- Screenshot: `05-save-selection.png`, `06-save-confirmed.png`

### Scenario 6: Return to accounts without re-authenticating

- After saving, navigate back to `/integrations/connect/google_business/accounts`
- Expected: page loads directly (no OAuth redirect)
- Expected: previously saved locations are pre-checked
- Change selection and save again
- Expected: success flash, no re-authentication
- Screenshot: `07-return-update.png`

### Scenario 7: Empty selection shows error

- On the accounts page, uncheck all locations
- Submit the form
- Expected: error message about selecting at least one location
- Screenshot: `08-empty-selection-error.png`

### Scenario 8: Failed OAuth callback shows error

- Navigate to `http://localhost:4070/integrations/oauth/callback/google_business?error=access_denied&error_description=User+denied+access`
- Expected: error flash message displayed, not a 500 error
- Screenshot: `09-oauth-error.png`

### Scenario 9: Unauthenticated access redirects

- Clear cookies
- Navigate to `http://localhost:4070/integrations/connect/google_business/accounts`
- Expected: redirected to `/users/log-in`
- Screenshot: `10-unauth-redirect.png`

### Scenario 10: Integrations index shows Google Business

- Log back in
- Navigate to `http://localhost:4070/integrations`
- Expected: Google Business listed with "Connected" badge, Sync Now and Edit Accounts buttons
- Screenshot: `11-integrations-list.png`

## Setup Notes

The Phoenix server must be started outside the sandbox (or with GBP API domains in the sandbox allowlist) for the location list to load from the real Google API. The required domains are `mybusinessbusinessinformation.googleapis.com` and `mybusinessaccountmanagement.googleapis.com` — these have been added to `.claude/settings.local.json`.

The OAuth flow requires the Cloudflare tunnel (`dev.metric-flow.app`) to be running since Google's redirect URI points there. If the tunnel is down, OAuth callbacks will fail.

## Result Path

`.code_my_spec/qa/519/result.md`
