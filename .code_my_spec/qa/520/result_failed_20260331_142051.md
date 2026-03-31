# QA Result

Story 520: Fetch and Select Google Business Profile Locations Across Multiple Accounts

## Status

fail

## Scenarios

### Scenario 1: Route and page access — /integrations/connect/google_business/accounts

**Result: PASS**

Navigated to `http://localhost:4070/integrations/connect/google_business/accounts` while logged in as `qa@example.com`. The page rendered the `:accounts` view_mode without redirecting away. The h2 heading read "Google Business — Select Accounts". Page text was checked for "Re-authenticate", "re-authenticate", "Re-connect", and "re-connect" — none found. URL remained at the accounts path throughout.

Evidence: `.code_my_spec/qa/520/screenshots/01-gbp-accounts-page.png`

### Scenario 2: Location list UI — single flat list, no account tabs

**Result: PASS**

No `[data-role='account-tab']` or `[data-role='account-switcher']` elements found on the page. The page rendered `[data-role='manual-entry']` and `[data-role='manual-property-input']` — the correct fallback UI when the live GBP API is not available with a test token. No account grouping tabs or switchers are present anywhere in the template.

Evidence: `.code_my_spec/qa/520/screenshots/02-gbp-location-list.png`

### Scenario 3: Location row fields — account name, title, address, store code

**Result: PARTIAL (live GBP API not available in QA)**

No location rows were rendered because the API requires valid OAuth credentials. The page showed only the manual entry form. Inspection of `connect.ex` (render_account_selection function, the `if @is_google_business` branch) confirms the GBP-specific template is implemented with the correct `data-role` attributes:
- `data-role="location-title"` — location name/title
- `data-role="location-account-name"` — account name for disambiguation
- `data-role="location-address"` — address (conditional on `property[:address]`)
- `data-role="location-store-code"` — store code (conditional on `property[:store_code]`)

These are rendered within an `if @is_google_business` conditional block when `@accounts != []`. The template structure matches the acceptance criteria. Live verification requires a real GBP OAuth token.

Evidence: `.code_my_spec/qa/520/screenshots/03-gbp-location-row-fields.png`

### Scenario 4: Save selection and success confirmation

**Result: PASS**

Filled `[data-role='manual-property-input']` with `accounts/123/locations/loc-001` and clicked `[data-role='save-selection']`. The form submitted and navigated to `/integrations/connect/google_business` with the flash message "Account selection saved successfully." The detail page showed "Location ID: accounts/123/locations/loc-001". Navigated back to the accounts page — the manual input was pre-filled with `accounts/123/locations/loc-001`. The save handler (`build_metadata_value(:google_business, account_id)`) correctly stores the location as an array `["accounts/123/locations/loc-001"]` under the key `"included_locations"`.

Evidence: `.code_my_spec/qa/520/screenshots/04-gbp-save-selection.png`, `.code_my_spec/qa/520/screenshots/05-gbp-save-confirmed.png`

### Scenario 5: Update location selection without re-authenticating

**Result: PASS**

After Scenario 4, navigated back to `http://localhost:4070/integrations/connect/google_business/accounts`. The URL contained no `accounts.google.com` or `oauth` segment — no OAuth redirect occurred. The manual input was pre-filled with `accounts/123/locations/loc-001`. Filled a new value `accounts/123/locations/loc-002` and saved. The detail page confirmed "Account selection saved successfully." flash with no re-authentication required. The selection can be updated at any time without triggering a new OAuth flow.

Evidence: `.code_my_spec/qa/520/screenshots/06-gbp-update-selection.png`

### Scenario 6: Missing/deleted location flagging (criterion 4862)

**Result: FAIL**

Updated the integration's `provider_metadata` via raw SQL to set `included_locations` to `["accounts/123/locations/deleted-loc-1"]`. Navigated to `/integrations/connect/google_business/accounts`. The page pre-filled the manual input with `accounts/123/locations/deleted-loc-1` but showed no warning or flag. No `[data-role='missing-location']` element was visible. No text containing "missing", "unavailable", "removed", or "revoked" was present.

Root cause: `compute_missing_locations/3` in `connect.ex` only computes missing locations when `fetched_accounts != []`:

```elixir
defp compute_missing_locations(:google_business, configured, fetched_accounts)
     when is_list(configured) and fetched_accounts != [] do
```

Since the live GBP API fails with a test token (the `Integrations.list_google_business_locations/1` call returns empty or an error), `@accounts` is always `[]` in the QA environment. With no fetched accounts to compare against, the function falls through to the catch-all that returns `[]`, so `@missing_locations` is always empty and the warning never renders.

The template already implements the full missing-location UI (`[data-role='missing-location']` and `[data-role='location-unavailable']`), but it is unreachable without real GBP API credentials.

Evidence: `.code_my_spec/qa/520/screenshots/07-gbp-missing-location-flag.png`

### Scenario 7: Unauthenticated access redirect

**Result: PASS**

Launched a fresh browser session (no cookies). Navigated to `http://localhost:4070/integrations/connect/google_business/accounts`. The URL immediately changed to `http://localhost:4070/users/log-in` — correctly redirected to the login page. The location selection UI was not shown to unauthenticated users. After logging back in, the browser correctly returned to the originally requested accounts page (stored redirect).

Evidence: `.code_my_spec/qa/520/screenshots/08-gbp-unauthenticated-redirect.png`

### Scenario 8: Integrations page shows google_business integration

**Result: PASS**

Navigated to `http://localhost:4070/integrations`. The page listed the Google Business integration with description "Business profile locations and reviews", status "Connected", connected date "Connected via Google Business on 2026-03-21", and the saved location ID `accounts/123/locations/deleted-loc-1`. Controls showed "Sync Now", "Edit Accounts", "Manage", and "Disconnect". The integrations index correctly displays the `included_locations` value for the Google Business provider using `Enum.join` for list values.

Evidence: `.code_my_spec/qa/520/screenshots/09-gbp-integrations-list.png`

### Scenario 9: Connect grid includes google_business provider

**Result: PASS**

Navigated to `http://localhost:4070/integrations/connect`. The platform selection grid showed all 6 canonical providers including "Google Business" with description "Business profile locations and reviews", a "Connected" badge, and a "Reconnect" button. `google_business` is included in `@canonical_providers` in `connect.ex` so it is always shown in the grid regardless of whether an integration exists.

Evidence: `.code_my_spec/qa/520/screenshots/10-gbp-connect-grid.png`

## Evidence

- `.code_my_spec/qa/520/screenshots/01-gbp-accounts-page.png` — accounts page renders at `/integrations/connect/google_business/accounts`
- `.code_my_spec/qa/520/screenshots/02-gbp-location-list.png` — manual entry form shown (no account tabs or switchers)
- `.code_my_spec/qa/520/screenshots/03-gbp-location-row-fields.png` — manual entry only (no fetched location rows; template structure verified in source)
- `.code_my_spec/qa/520/screenshots/04-gbp-save-selection.png` — manual input filled with `accounts/123/locations/loc-001` before save
- `.code_my_spec/qa/520/screenshots/05-gbp-save-confirmed.png` — detail page after save showing "Account selection saved successfully." and saved location ID
- `.code_my_spec/qa/520/screenshots/06-gbp-update-selection.png` — accounts page updated to loc-002 with no re-auth redirect
- `.code_my_spec/qa/520/screenshots/07-gbp-missing-location-flag.png` — accounts page with deleted-loc-1 pre-filled but no warning shown
- `.code_my_spec/qa/520/screenshots/08-gbp-unauthenticated-redirect.png` — login page shown after unauthenticated access attempt
- `.code_my_spec/qa/520/screenshots/09-gbp-integrations-list.png` — integrations index showing Google Business as connected with saved location displayed
- `.code_my_spec/qa/520/screenshots/10-gbp-connect-grid.png` — connect grid showing Google Business with Connected badge

## Issues

### Missing-location warning never shown when GBP API returns no locations

#### Severity
HIGH

#### Description
When a previously configured location ID is no longer available (deleted or revoked), the accounts page shows no warning. The manual entry field pre-fills with the stale location ID silently.

The `compute_missing_locations/3` function in `connect.ex` has the guard `when is_list(configured) and fetched_accounts != []`. This means missing-location detection only runs when the live API successfully returns at least one location to compare against. When the API returns an empty list (due to invalid/test credentials, a 401/403 error, or genuinely no locations), the comparison never runs and `@missing_locations` is always `[]`.

The fix would be to also flag configured locations as missing when the API returns an error (`accounts_error` is set and `raw_selection` is non-empty), so users know their previously configured location could not be verified — rather than silently showing a stale location ID in the input.

Reproduced by: setting `included_locations` to `["accounts/123/locations/deleted-loc-1"]` in the integration's `provider_metadata` and navigating to `/integrations/connect/google_business/accounts` with a test (non-real) OAuth token. The manual input shows the stale ID with no indication it may be invalid.
