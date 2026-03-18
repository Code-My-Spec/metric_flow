# QA Story Brief

Story 440 — Handle Expired or Invalid OAuth Credentials

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind `:require_authenticated_user`)

## Auth

Log in as the QA owner user using MCP tools:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

The base seeds must be run before testing. Verify by logging in — if login succeeds as `qa@example.com`, seeds are in place.

This story requires a connected integration with an **expired** access token. Run the story-specific seed to create one:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds_440.exs
```

This script creates a `google_analytics` integration for `qa@example.com` with an `expires_at` timestamp in the past, so the integration shows as connected but its token is expired.

If the Phoenix server is already running when you try to run seeds, use the server-safe form:

```bash
MIX_ENV=dev mix run --no-start -e "
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
{:ok, _} = MetricFlow.Repo.start_link([])
" priv/repo/qa_seeds_440.exs
```

Note: Prefer verifying the integration exists via the browser rather than re-seeding. If you can see a "Connected" Google Analytics integration on `/integrations`, seeds are in place.

## Setup Notes

This story tests the expired OAuth credentials UX. The core acceptance criteria involve:

1. **Token expiry → reconnection UI**: When a connected integration has an expired token and the user triggers Sync Now, the system returns `:not_connected` and shows a flash error containing "token has expired. Please reconnect."
2. **Warning indicator**: The reconnection indicator surfaces as a flash error message on the integrations page, not as a badge state change on the card itself (the card always shows "Connected" based on integration existence, not token validity).
3. **Reconnect button on detail page**: Navigating to `/integrations/connect/google_analytics` when connected shows a "Reconnect" button (OAuth anchor with `data-role="oauth-connect-button"`).
4. **Historical data preserved**: After triggering a failed sync, the integration record still exists and the "Connected" badge is still shown — data is not deleted.
5. **No email notification**: The current implementation does not send an email notification on token expiry — this acceptance criterion is not implemented. Report as an issue if absent.

The BDD spec also tests behavior via `{:sync_failed, ...}` PubSub messages sent directly to the LiveView process. For browser QA, the equivalent is clicking "Sync Now" on the expired integration, which triggers the same code path via `DataSync.sync_integration/2` returning `{:error, :not_connected}`.

## What To Test

### Scenario 1: Unauthenticated redirect to integrations page

- Visit `http://localhost:4070/integrations` without logging in
- Expected: redirected to `/users/log-in` (HTTP 302)
- Use `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations` to verify

### Scenario 2: Integrations page loads with connected integration

- Log in as `qa@example.com`
- Navigate to `http://localhost:4070/integrations`
- Expected: page loads, shows "Google Analytics" in "Connected Platforms" section with a "Connected" badge
- Take screenshot: `01_integrations_page_connected.png`

### Scenario 3: Sync Now on expired integration shows reconnection message (AC: status changes / warning indicator)

- On the integrations page, find the Google Analytics integration card
- Click the "Sync Now" button on the Google Analytics card
- Expected: a flash error appears containing "token has expired" and/or "reconnect" text
- The integration card should still show "Connected" (historical data preserved — AC: system does not delete data)
- Take screenshot: `02_sync_expired_flash_error.png`

### Scenario 4: Connect detail page shows Reconnect button (AC: user can click Reconnect)

- Navigate to `http://localhost:4070/integrations/connect/google_analytics`
- Expected: page shows the provider detail card with:
  - A "Connected" badge
  - An anchor or button with text "Reconnect" (`data-role="oauth-connect-button"`)
  - A "Select Accounts" button
  - A "Back to integrations" link
- Take screenshot: `03_detail_page_reconnect_button.png`

### Scenario 5: Historical data not deleted after credentials expire (AC: system does not delete historical data)

- After triggering the failed sync in Scenario 3, navigate back to `/integrations`
- Expected: Google Analytics is still listed in "Connected Platforms" — the integration record was not deleted
- The "Connected" badge is still visible
- Take screenshot: `04_data_preserved_after_expiry.png`

### Scenario 6: Reconnect button re-initiates OAuth flow (AC: user can click Reconnect to re-initiate OAuth)

- On the `/integrations/connect/google_analytics` detail page
- Verify the "Reconnect" link (`[data-role="oauth-connect-button"]`) has an `href` attribute pointing to an OAuth authorize URL (not empty, not a relative path)
- Use `mcp__vibium__browser_get_attribute(selector: "[data-role='oauth-connect-button']", attribute: "href")` to inspect the URL
- Expected: the href is a full provider OAuth URL (e.g., `https://accounts.google.com/...`)
- Note: do NOT click the link — it opens an actual OAuth flow in a new tab and requires real credentials
- Take screenshot: `05_reconnect_oauth_href.png`

### Scenario 7: Check for email notification (AC: user receives email notification)

- Navigate to `http://localhost:4070/dev/mailbox`
- Look for any emails about expired credentials, token expiry, or reconnection reminders
- Expected outcome depends on implementation — report absent if no such email exists
- Take screenshot: `06_dev_mailbox.png`

## Result Path

`.code_my_spec/qa/440/result.md`
