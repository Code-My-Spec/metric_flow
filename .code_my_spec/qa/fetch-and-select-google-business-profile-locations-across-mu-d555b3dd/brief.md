# QA Story Brief

Story 520: Fetch and Select Google Business Profile Locations Across Multiple Accounts

## Tool

web (Vibium MCP browser tools — all routes are LiveView behind `:require_authenticated_user`)

## Auth

Log in as the QA owner user via the password form:

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

## Seeds

The base QA seeds create `qa@example.com` with the "QA Test Account". Verify login works rather than re-running seeds (re-running fails when the server is already running due to Cloudflare tunnel conflict).

Story 520 requires a `google_business` integration record for the QA user. Create one via a seed script if it does not already exist:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run --no-start -e "
  Application.ensure_all_started(:postgrex)
  Application.ensure_all_started(:ecto)
  {:ok, _} = MetricFlow.Repo.start_link([])

  alias MetricFlow.Repo
  alias MetricFlow.Accounts.User
  import Ecto.Query

  user = Repo.one(from u in User, where: u.email == ^\"qa@example.com\")

  if user do
    alias MetricFlow.Integrations.Integration
    existing = Repo.one(from i in Integration, where: i.user_id == ^user.id and i.provider == :google_business)
    if is_nil(existing) do
      %Integration{}
      |> Integration.changeset(%{
        user_id: user.id,
        provider: :google_business,
        access_token: \"test_access_token_gbp\",
        refresh_token: \"test_refresh_token_gbp\",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        granted_scopes: [\"https://www.googleapis.com/auth/business.manage\"],
        provider_metadata: %{
          \"email\" => \"qa@example.com\",
          \"google_business_account_ids\" => [\"accounts/123\", \"accounts/456\"]
        }
      })
      |> Repo.insert!()
      IO.puts(\"Created google_business integration for qa@example.com\")
    else
      IO.puts(\"google_business integration already exists\")
    end
  else
    IO.puts(\"ERROR: qa@example.com not found — run base seeds first\")
  end
"
```

For the \"missing location\" scenario (criterion 4862), a second integration variant is needed that has `included_locations` containing a location ID that won't appear in the live API. This can be set up by editing the integration's `provider_metadata` directly in the database or via a second seed run with `"included_locations" => ["accounts/123/locations/deleted-loc-1"]`.

Note: The `google_business` provider is a valid provider atom in the system (defined in `Integration.changeset`), but the `Connect` LiveView's `fetch_provider_accounts/3` has no clause for `:google_business` — the catch-all returns `{[], nil}`. Accessing `/integrations/connect/google_business/accounts` will land on the accounts view with an empty list and the manual-entry fallback. This is the expected starting behavior to verify against acceptance criteria.

## What To Test

### Scenario 1: Route and page access — /integrations/connect/google_business/accounts

- Navigate to `http://localhost:4070/integrations/connect/google_business/accounts` while logged in
- Expected: page renders the "Select Accounts" view (`:accounts` view_mode) — NOT redirected away
- Verify the page heading shows "Google Business" in the title area
- Verify the page does NOT show "Re-authenticate", "re-authenticate", "Re-connect", or "re-connect" text (AC: user can update selection at any time without re-authenticating)
- Screenshot: `01-gbp-accounts-page.png`

### Scenario 2: Location list UI — single flat list, no account tabs

- On the `/integrations/connect/google_business/accounts` page
- Verify no `[data-role='account-tab']` or `[data-role='account-switcher']` elements exist (AC: single flat list, not grouped by account)
- Verify the page renders some form of selection UI — either `[data-role='location-list']`, `[data-role='account-list']`, `[data-role='account-selection']`, or `input[type='checkbox']`/`input[type='radio']`
- Screenshot: `02-gbp-location-list.png`

### Scenario 3: Location row fields — account name, title, address, store code

- On the same accounts page, inspect the rendered HTML
- Verify that location rows (if any are displayed from the API) include account name for disambiguation — look for `[data-role='location-account-name']`, `[data-role='location-row']`, or text containing "account" or "Account"
- Verify that location row fields support: location name/title (`[data-role='location-title']` or `[data-role='location-name']`), address (`[data-role='location-address']`), and store code when present (`[data-role='location-store-code']`)
- Because the live API is not connected in QA (no real OAuth token), focus verification on the UI structure: does the template render the fields when data is present? Check the HTML source with `browser_get_html()` to see the data-role attributes defined
- Screenshot: `03-gbp-location-row-fields.png`

### Scenario 4: Save selection and success confirmation

- On `/integrations/connect/google_business/accounts`, locate the `[data-role='save-selection']` button or a "Save Selection" button
- If a manual-entry input is present (`[data-role='manual-property-input']`), fill it with `accounts/123/locations/loc-001`
- Submit the form by clicking `[data-role='save-selection']`
- Expected: success flash message ("Account selection saved successfully.") OR redirect to `/integrations/connect/google_business`
- Verify the saved value is stored: navigate back to the accounts page and check that the manual input pre-fills with the saved value
- Screenshot: `04-gbp-save-selection.png`, `05-gbp-save-confirmed.png`

### Scenario 5: Update location selection without re-authenticating

- After completing Scenario 4, navigate back to `http://localhost:4070/integrations/connect/google_business/accounts`
- Verify the page loads without triggering an OAuth redirect (URL should NOT contain `accounts.google.com` or `oauth`)
- Verify the previously saved location ID is pre-filled in the manual entry or checked in the list
- Fill a new value (`accounts/123/locations/loc-002`) and save again
- Expected: success flash or redirect — no re-authentication required
- Screenshot: `06-gbp-update-selection.png`

### Scenario 6: Missing/deleted location flagging (criterion 4862)

- Set up the integration to have `included_locations: ["accounts/123/locations/deleted-loc-1"]` in `provider_metadata`
- Navigate to `http://localhost:4070/integrations/connect/google_business/accounts`
- Expected: the page should flag the previously configured location as missing/unavailable/removed, rather than silently dropping it
- Look for: `[data-role='missing-location']`, `[data-role='location-warning']`, `[data-role='location-unavailable']`, `.location-missing`, `.location-warning`, or text containing "missing", "unavailable", "removed", "revoked", "warning", or the location ID "deleted-loc-1"
- Screenshot: `07-gbp-missing-location-flag.png`

### Scenario 7: Unauthenticated access redirect

- Clear cookies: `mcp__vibium__browser_delete_cookies()`
- Navigate to `http://localhost:4070/integrations/connect/google_business/accounts`
- Expected: redirected to `/users/log-in` (not shown the location selection UI)
- Screenshot: `08-gbp-unauthenticated-redirect.png`

### Scenario 8: Integrations page shows google_business integration

- Log back in as `qa@example.com`
- Navigate to `http://localhost:4070/integrations`
- Expected: the integrations list shows a "Google Business" or `google_business` entry (verifying integration visibility)
- Screenshot: `09-gbp-integrations-list.png`

### Scenario 9: Connect grid includes google_business provider

- Navigate to `http://localhost:4070/integrations/connect`
- Verify the platform selection grid does NOT show a bare "Google Business" card (or does — note the current state)
- Note: `google_business` is NOT in `@canonical_providers` in `connect.ex` — it only appears if the user already has an integration for it. Verify whether the card appears after the integration was created in seeds
- Screenshot: `10-gbp-connect-grid.png`

## Setup Notes

The `Connect` LiveView (`lib/metric_flow_web/live/integration_live/connect.ex`) has no `fetch_provider_accounts/3` clause for `:google_business` — the catch-all returns `{[], nil}`. This means the accounts page will show the manual-entry fallback rather than a fetched location list. The acceptance criteria describe a full location-fetching implementation with pagination, multi-account merging, and missing-location flagging. Tests that verify the full list UI (criteria 4854–4857, 4859, 4862) are likely to fail because the feature is not yet implemented.

The test should verify what IS present (the route works, manual entry works, save/redirect works) and clearly report what is MISSING (location list UI, multi-account merging, pagination, missing-location flagging).

The `provider_metadata` key for Google Business locations should use `"included_locations"` (array) per the acceptance criteria, but the current `metadata_key_for_provider/1` catch-all in `connect.ex` maps unknown providers to `"property_id"`. This is a likely implementation gap to report.

## Result Path

`.code_my_spec/qa/520/result.md`
