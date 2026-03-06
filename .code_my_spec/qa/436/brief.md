# QA Story Brief

Story 436: View and Manage Platform Integrations

## Tool

web (Vibium MCP browser tools — the `/integrations` route is a LiveView behind session auth)

## Auth

Run seeds first, then log in via the browser:

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

Run the base seed script before testing. It creates the owner user and team account but does NOT create integrations — those must be created via the integration connect flow or will appear as "Available Platforms" only.

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

To test connected integration scenarios (platform name, connected date, sync status, selected accounts, disconnect, reconnect), an integration record must exist in the database. The base seeds do not create one. Use the Elixir seed inline to create a test integration for `qa@example.com`:

```bash
mix run -e '
alias MetricFlow.{Repo, Users}
alias MetricFlow.Integrations.Integration

user = Users.get_user_by_email("qa@example.com")

existing = Repo.get_by(Integration, user_id: user.id, provider: :google_ads)

if is_nil(existing) do
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google_ads,
    access_token: "qa_test_token",
    refresh_token: "qa_test_refresh",
    expires_at: DateTime.add(DateTime.utc_now(), 86400, :second),
    granted_scopes: ["https://www.googleapis.com/auth/adwords"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "selected_accounts" => ["Campaign Alpha", "Campaign Beta"]
    }
  })
  |> Repo.insert!()
  IO.puts("Created google_ads integration for qa@example.com")
else
  IO.puts("Integration already exists")
end
'
```

Note: This single `mix run -e` call is acceptable here because it is a one-off seed step, not a loop. For subsequent runs it is idempotent via the `Repo.get_by` check.

## What To Test

### Scenario 1: Unauthenticated redirect (AC: auth guard)

- Visit `http://localhost:4070/integrations` without logging in (clear cookies first or use a fresh curl check)
- Expected: redirected to `/users/log-in` — the page does not render integration content

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations
# Expected: 302
```

### Scenario 2: Page loads with integration list heading (AC: view list)

- Navigate to `http://localhost:4070/integrations` while logged in as `qa@example.com`
- Expected: page loads (no redirect), shows "Integrations" h1 heading
- Expected: "Connected Platforms" section visible when integration record exists
- Expected: "Available Platforms" section always visible
- Screenshot: `integrations-index.png`

Selectors to verify:
- `h1` containing text "Integrations"
- `[data-role='integrations-list']` OR presence of "Integration" in page text
- `[data-role='integration-card']` — at least one card present

### Scenario 3: Marketing platform name visible (AC: each integration shows platform name)

- On the integrations page, find the connected integration card for Google Ads
- Expected: `[data-role='integration-platform-name']` element exists and contains "Google Ads"
- Screenshot: `integration-platform-name.png`

### Scenario 4: Connected date shown per integration (AC: each integration shows connected date)

- On the integrations page
- Expected: `[data-role='integration-connected-date']` element exists within `[data-role='integration-row']`
- Expected: text contains "Connected" followed by a date (e.g., "Connected Mar 05, 2026")

### Scenario 5: Sync status shown per integration (AC: each integration shows sync status)

- On the integrations page
- Expected: `[data-role='integration-sync-status']` element exists
- Expected: badge shows "Connected" text (`.badge-success`)

### Scenario 6: Selected accounts visible per integration (AC: user can see selected ad accounts)

- On the integrations page, find the connected Google Ads card
- Expected: `[data-role='integration-selected-accounts']` element visible within the card
- Expected: text contains "Campaign Alpha" and "Campaign Beta" (from seed data)
- Screenshot: `integration-selected-accounts.png`

### Scenario 7: Integration detail link present (AC: selected accounts/view detail)

- On the integrations page
- Expected: `[data-role='integration-detail-link']` link present on connected card — clicking navigates to `/integrations/connect/google_ads`

### Scenario 8: Edit accounts link present (AC: modify selected accounts without re-authenticating)

- On the integrations page
- Expected: `[data-role='edit-integration-accounts']` link present on connected card
- Expected: clicking navigates to `/integrations/connect/google_ads/accounts` without an OAuth redirect or re-authenticate prompt

### Scenario 9: Disconnect button present and modal opens (AC: disconnect/remove integration)

- On the integrations page, click `[data-role='disconnect-integration']`
- Expected: disconnect confirmation modal appears (`[class*='modal-open']`)
- Expected: modal heading contains "Disconnect Google Ads?"
- Screenshot: `disconnect-modal.png`

### Scenario 10: Disconnect warning message shown (AC: disconnecting shows warning about historical data)

- After clicking disconnect, while the modal is open
- Expected: `[data-role='disconnect-warning']` element visible
- Expected: text contains "Historical data will remain" AND "No new data will sync after disconnecting"

### Scenario 11: Confirm/cancel options in disconnect modal (AC: disconnect warning with confirm/cancel)

- Modal open after clicking disconnect
- Expected: `[data-role='confirm-disconnect']` button present (text "Disconnect")
- Expected: `[data-role='cancel-disconnect']` button present (text "Cancel")
- Click Cancel — modal closes, integration remains connected
- Screenshot: `disconnect-cancelled.png`

### Scenario 12: Confirm disconnect removes integration from connected list (AC: disconnect removes integration)

- With integration present, click disconnect then confirm
- Expected: integration card disappears from "Connected Platforms"
- Expected: flash message contains "Disconnected from Google Ads. Historical data is retained; no new data will sync."
- Expected: Google Ads now shows under "Available Platforms" with a "Connect" button
- Screenshot: `integration-disconnected.png`

### Scenario 13: Reconnect option visible for disconnected platform (AC: reconnect previously disconnected platform)

- After disconnecting (or viewing a platform with no connected integration)
- Expected: `[data-role='reconnect-integration']` button present in Available Platforms section
- Expected: button text is "Connect" (the reconnect action)
- Click the Connect button — expected: flash message "Reconnect Google Ads: authorize your account on the Connect page."
- Screenshot: `reconnect-button.png`

### Scenario 14: Disconnected vs connected platforms visually distinguishable (AC: reconnect/visual state)

- On the integrations page
- Expected: connected platforms show `.badge-success` with "Connected" text
- Expected: available (disconnected) platforms show `.badge-ghost` with "Not connected" text
- Expected: `data-status="connected"` on sync status badge, `data-status="available"` on available platform cards

### Scenario 15: Uniform card layout for all integrations including QuickBooks (AC: uniform treatment)

- On the integrations page
- Expected: all cards share `[data-role='integration-card']`
- Expected: NO `[data-role='quickbooks-special-section']` element exists anywhere on the page
- Expected: all visible integration cards use the same structure regardless of provider

## Result Path

`.code_my_spec/qa/436/result.md`
