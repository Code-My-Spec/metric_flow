# QA Story Brief

Story 436 — View and Manage Platform Integrations

## Tool

web (vibium MCP browser tools — this is a LiveView page at `/integrations`)

## Auth

Log in fresh at the start of every run. Sessions cannot be saved or restored.

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

Do NOT use `wait(selector: "body")` after clicking the login button — the page performs a
full HTTP redirect and the DOM will briefly be empty, causing a timeout.

## Seeds

The base seeds create a Google integration for `qa@example.com` with `selected_accounts`
set to `["Campaign Alpha", "Campaign Beta"]`. This is the `owner_with_integrations` fixture
required by most scenarios.

Preferred approach — verify the seed data is already in place by logging in. If login
succeeds as `qa@example.com`, seeds are active.

If the integration is missing from `/integrations` after login, run seeds:

```bash
# When Phoenix server is already running (typical):
cd /Users/johndavenport/Documents/github/metric_flow
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs

# When server is NOT running:
mix run priv/repo/qa_seeds.exs
```

Seed data provided:
- Owner: `qa@example.com` / `hello world!`
- Google integration (provider `:google`) with `selected_accounts: ["Campaign Alpha", "Campaign Beta"]`
- This covers both Google Analytics and Google Ads platforms (both map to provider `:google`)
- QuickBooks and Facebook Ads are NOT connected (they appear as "Available Platforms")

## What To Test

### Scenario 1: Authenticated user can navigate to integrations page (AC: view list of all connected integrations)

1. Navigate to `http://localhost:4070/integrations`
2. Verify the page loads (no redirect)
3. Verify H1 heading "Integrations" is present
4. Verify subtitle "Manage your connected marketing platforms" is present
5. Verify the "Connect a Platform" button/link is present
6. Screenshot: `01-integrations-index.png`

### Scenario 2: Integrations page shows marketing and financial platforms (AC: view list)

1. On `/integrations` (after login and seeds in place)
2. Verify "Connected Platforms" section heading is shown (Google is connected)
3. Verify "Available Platforms" section heading is shown (QuickBooks, Facebook Ads not connected)
4. Verify "Google Analytics" platform name appears in the page
5. Verify "Google Ads" platform name appears in the page
6. Verify "QuickBooks" platform name appears in the page
7. Verify "Facebook Ads" platform name appears in the page
8. Screenshot: `02-connected-and-available-sections.png`

### Scenario 3: Each integration shows platform name, connected date, and sync status (AC: platform name, connected date, sync status)

1. On `/integrations` with Google connected
2. Verify `[data-role='integration-platform-name']` elements are present within `[data-role='integration-row']`
3. Verify `[data-role='integration-connected-date']` element is present (shows "Connected via Google on YYYY-MM-DD")
4. Verify `[data-role='integration-sync-status']` element is present
5. Verify `[data-role='integration-card']` wraps each platform
6. Screenshot: `03-platform-name-date-status.png`

### Scenario 4: Integration shows selected accounts (AC: see which accounts are selected)

1. On `/integrations` with Google connected (seeds provide `["Campaign Alpha", "Campaign Beta"]`)
2. Verify `[data-role='integration-selected-accounts']` element is present within the integration row
3. Verify the text "Campaign Alpha" or "Campaign Beta" appears in the selected accounts section
4. Verify `[data-role='integration-row'] [data-role='integration-selected-accounts']` is nested correctly
5. Screenshot: `04-selected-accounts.png`

### Scenario 5: Edit accounts link present (AC: modify selected accounts without re-authenticating)

1. On `/integrations` with Google connected
2. Verify `[data-role='edit-integration-accounts']` element is present
3. Verify `[data-role='integration-detail-link']` (Manage link) is present
4. Click the "Edit Accounts" link — it should navigate to `/integrations/connect/google/accounts` (no OAuth redirect)
5. Verify the URL changes to `/integrations/connect/google/accounts` — no redirect to `accounts.google.com`
6. Screenshot: `05-edit-accounts-link.png`
7. Navigate back to `/integrations` for subsequent scenarios

### Scenario 6: Disconnect button is present (AC: disconnect or remove an integration)

1. On `/integrations` with Google connected
2. Verify `[data-role='disconnect-integration']` button is visible within the Google platform card
3. Verify the button text is "Disconnect"
4. Screenshot: `06-disconnect-button-present.png`

### Scenario 7: Disconnect confirmation modal — warning text (AC: shows warning about historical data)

1. On `/integrations` with Google connected
2. Click `[data-role='disconnect-integration']` for the google_analytics or google_ads card
   - Note: both maps to provider `google`, clicking either opens the modal for the Google provider
   - Use selector: `[data-platform='google_analytics'] [data-role='disconnect-integration']`
     or `[data-platform='google_ads'] [data-role='disconnect-integration']`
3. Verify the disconnect modal appears (`[data-role='disconnect-modal']` or `.modal-open`)
4. Verify modal heading contains "Disconnect Google?"
5. Verify `[data-role='disconnect-warning']` element is present
6. Verify warning text contains "historical data" (case insensitive)
7. Verify warning text contains "no new data will sync" or "no new data" (case insensitive)
8. Screenshot: `07-disconnect-modal-warning.png`

### Scenario 8: Disconnect modal has confirm and cancel options (AC: disconnect/remove flow)

1. With disconnect modal open (from Scenario 7, or re-trigger)
2. Verify `[data-role='confirm-disconnect']` button is present
3. Verify `[data-role='cancel-disconnect']` button is present
4. Click `[data-role='cancel-disconnect']`
5. Verify the modal disappears (not visible)
6. Verify the integration is still in "Connected" state
7. Screenshot: `08-disconnect-cancelled.png`

### Scenario 9: Complete disconnect flow (AC: disconnect removes active connection; reconnect available)

1. On `/integrations` with Google connected
2. Click `[data-role='disconnect-integration']` on a Google platform card
3. With modal open, click `[data-role='confirm-disconnect']`
4. Verify flash message contains "Disconnected from Google" and "Historical data is retained"
5. Verify the Google platforms move to the "Available Platforms" section (data-status="available")
6. Verify a "Connect Google" button appears (reconnect entry point)
7. Screenshot: `09-after-disconnect.png`

### Scenario 10: Reconnect option for disconnected platform (AC: reconnect a previously disconnected platform)

1. After Scenario 9 (Google disconnected), on `/integrations`
2. Verify `[data-role='reconnect-integration']` element is present for the Google platforms
3. Verify "Connect Google" text is visible
4. Verify the platforms show `data-status="available"` (not `data-status="connected"`)
5. Click the "Connect Google" link — verify it navigates to `/integrations/connect`
6. Screenshot: `10-reconnect-available.png`

### Scenario 11: Uniform card layout — no QuickBooks special UI (AC: all integrations treated uniformly)

1. On `/integrations` (QuickBooks is in "Available Platforms" since it is not connected)
2. Verify `[data-platform='quickbooks']` is present with `[data-role='integration-card']`
3. Verify there is NO `[data-role='quickbooks-special-section']` element
4. Verify `[data-role='integration-platform-name']` is present inside the QuickBooks card
5. Verify all `[data-role='integration-card']` elements share a uniform structure
6. Screenshot: `11-uniform-card-layout.png`

### Scenario 12: Unauthenticated access is blocked (AC: auth required)

1. Using `curl` or a fresh browser with no session:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations
   ```
2. Expected: `302` (redirect to login)
3. If testing via browser: clear cookies, navigate to `/integrations`, verify redirect to `/users/log-in`

## Setup Notes

The seed script creates one Google OAuth integration. This makes both Google Analytics and
Google Ads appear in "Connected Platforms" (both map to provider `:google`). QuickBooks and
Facebook Ads have no integration record, so they appear in "Available Platforms".

After running Scenario 9 (disconnect), the Google integration is deleted from the database.
Subsequent scenarios that need a connected Google integration require re-running seeds or
re-connecting via the OAuth flow. Plan the test order so disconnect scenarios run last, or
re-run seeds between disconnect and reconnect tests.

The disconnect `phx-click` event is `confirm_disconnect` (opens the modal) followed by
`disconnect` (confirms deletion). The "Disconnect" button on the card triggers `confirm_disconnect`,
not immediate deletion. The confirm button inside the modal triggers `disconnect`.

## Result Path

`.code_my_spec/qa/436/result.md`
