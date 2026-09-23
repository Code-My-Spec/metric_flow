# QA Story Brief

Story 434: Connect Marketing Platform via OAuth

## Tool

web (Vibium MCP browser automation for all LiveView pages; curl for unauthenticated redirect check)

## Auth

Log in as the QA owner user using the password form:

1. Launch browser: `mcp__vibium__browser_launch(headless: true)`
2. Navigate: `mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")`
3. Scroll password form into view: `mcp__vibium__browser_scroll(selector: "#login_form_password")`
4. Fill email: `mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")`
5. Fill password: `mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")`
6. Click login: `mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")`
7. Wait for redirect: `mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)`
8. Verify URL is not the login page: `mcp__vibium__browser_get_url()`

Credentials: `qa@example.com` / `hello world!`

## Seeds

Verify login works. If login fails, run:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

If the Phoenix server is already running, use:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

No story-specific seeds are required. The base seeds create a QA owner user and "QA Test Account" which is sufficient for all scenarios. The integration tests simulate OAuth by visiting callback URLs with test parameters — no real OAuth provider credentials are needed.

## Setup Notes

The OAuth connect flow uses these provider keys (not individual platforms):

- `google` — covers Google Ads AND Google Analytics under one OAuth connection
- `facebook_ads` — Facebook advertising
- `quickbooks` — QuickBooks financial data

Valid routes:
- `/integrations/connect` — provider selection grid
- `/integrations/connect/google` — Google provider detail
- `/integrations/connect/facebook_ads` — Facebook provider detail
- `/integrations/connect/quickbooks` — QuickBooks provider detail
- `/integrations/connect/google/accounts` — Google account selection (requires google integration to exist first)
- `/integrations/oauth/callback/google?error=access_denied` — simulates a denied OAuth callback (no real code needed)
- `/integrations/oauth/callback/google?code=test_auth_code&state=test_state` — simulates a callback with test credentials (will fail token exchange, showing error result view)

For scenarios that require an existing connected integration (account selection page), use the Google provider after a real or simulated callback. If the QA account already has a google integration from a previous run, account selection will be accessible directly. If not, simulate via the callback URL.

## What To Test

### Scenario 1 — Platform selection page lists all supported providers

Navigate to `http://localhost:4070/integrations/connect` while logged in.

Expected:
- Page title/heading contains "Connect a Provider"
- Three provider cards are visible in a grid
- Card with `data-platform="google"` shows "Google" and "Google Ads and Google Analytics"
- Card with `data-platform="facebook_ads"` shows "Facebook"
- Card with `data-platform="quickbooks"` shows "QuickBooks"
- Each card has a `[data-role='connect-button']` button labeled "Connect" or "Reconnect"
- No "Re-authenticate" text on the page

Take screenshot: `01-platform-selection.png`

### Scenario 2 — Connect buttons are present for each provider

On the same `/integrations/connect` page:

Expected:
- `[data-platform='google'] [data-role='connect-button']` is present
- `[data-platform='facebook_ads'] [data-role='connect-button']` is present
- `[data-platform='quickbooks'] [data-role='connect-button']` is present

Take screenshot: `02-connect-buttons.png`

### Scenario 3 — Per-provider detail view shows OAuth initiation link

Navigate to `http://localhost:4070/integrations/connect/google`.

Expected:
- Provider name "Google" appears on the page
- `[data-role='oauth-connect-button']` link is present
- The link has `target="_blank"` attribute
- The href points to a Google OAuth authorization URL (starts with `https://accounts.google.com/` or similar)
- "Connect Google" or "Reconnect" button text is present
- "Back to integrations" navigation link is present

Take screenshot: `03-google-detail.png`

Also navigate to `http://localhost:4070/integrations/connect/facebook_ads` and verify the Facebook detail view renders the same structure.

Take screenshot: `03b-facebook-detail.png`

### Scenario 4 — Detail view does not show re-authenticate option

On `/integrations/connect/google`:

Expected:
- "Re-authenticate" text does not appear
- "Re-connect" (with hyphen) text does not appear
- Page renders without error

### Scenario 5 — Account selection page renders correctly

The accounts page at `/integrations/connect/google/accounts` requires an existing google integration. If the QA account already has a google integration, navigate directly. If not, first simulate an OAuth callback to create one:

```
http://localhost:4070/integrations/oauth/callback/google?code=test_auth_code&state=test_state
```

This will fail the token exchange and show the error result view — do not try to create a real integration this way. Instead, check `/integrations/connect/google` first. If a google integration already exists (page shows "Connected" badge), navigate to the accounts page:

Navigate to `http://localhost:4070/integrations/connect/google/accounts`.

If no integration exists, this redirects to `/integrations/connect/google` with an error flash — note this as expected behavior and skip accounts-specific assertions.

If the accounts page loads:
- Page heading contains "Google — Select Accounts"
- Form element `[data-role='account-selection']` is present
- `[data-role='save-selection']` button is present (labeled "Save Selection")
- Either `[data-role='account-list']` with radio inputs OR `[data-role='manual-property-input']` manual entry field is present

Take screenshot: `05-google-accounts.png`

Also navigate to `http://localhost:4070/integrations/connect/facebook_ads/accounts` (if facebook_ads integration exists). Verify the heading shows "Facebook — Select Accounts" and text does NOT contain "GA4 Property ID" (that text is Google-specific and would be a bug).

Take screenshot: `05b-facebook-accounts.png`

### Scenario 6 — Integration not saved before OAuth completion

Navigate to `http://localhost:4070/integrations/connect/google` with a fresh session (no prior google integration in QA account, or use the member user).

Expected:
- "Integration saved" does not appear
- "Integration active" does not appear (unless there's an existing integration with the active result view)
- `[data-role='oauth-connect-button']` labeled "Connect Google" is present (not connected state)

If QA account already has a google integration, log out and log in as `qa-member@example.com` (password: `hello world!`) to test this scenario with a clean account.

Take screenshot: `06-not-saved-before-oauth.png`

### Scenario 7 — OAuth callback success result view

This tests the `:result` view mode that appears when the callback redirects back with a flash.

Navigate to `http://localhost:4070/integrations/connect/google`. Check the current URL. The result view is triggered by the flash from the OAuth controller, not the URL. If the flash has already been consumed, the page shows the detail view.

To test the error result view (which we can trigger without real OAuth), visit:

```
http://localhost:4070/integrations/oauth/callback/google?error=access_denied
```

After the redirect lands on `/integrations/connect/google`, verify:
- "Connection Failed" heading appears
- Error message text is present
- "Try again" link is present pointing to `/integrations/connect/google`
- "Back to integrations" link is present
- "Integration saved" and "successfully connected" do NOT appear

Take screenshot: `07-callback-error-result.png`

### Scenario 8 — Error callback with error_description

Visit:
```
http://localhost:4070/integrations/oauth/callback/google?error=access_denied&error_description=User+denied+access
```

After the redirect, verify the error result view renders with an error message visible to the user.

Take screenshot: `08-access-denied-error.png`

### Scenario 9 — Unauthenticated user is redirected

Clear cookies to simulate a logged-out state, then navigate to `http://localhost:4070/integrations/connect`.

Verify redirect to `/users/log-in`. Can also verify via curl:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/connect
```

Expected: `302`

Take screenshot: `09-unauthenticated-redirect.png`

### Scenario 10 — Integration page is scoped to logged-in account

Log in as `qa@example.com` and navigate to `http://localhost:4070/integrations`.

Expected:
- Page renders without showing another account's data
- No "Transfer to agency", "Assign to agency", or "Move to agency" text

Also check `/integrations/connect/google`:
- No transfer options appear
- Page content contains "Connect" or "Google"

Take screenshot: `10-integrations-scoped.png`

## Result Path

`.code_my_spec/qa/434/result.md`
