# Qa Result

## Status

pass

## Scenarios

### Scenario 1: Route and page access

**Status:** pass

Navigated to `/integrations/connect/google_business/accounts` while logged in as `qa@example.com`. Page rendered the "Google Business — Select Accounts" heading with chooser text "Choose which business locations to sync reviews and metrics from." No "re-authenticate" or "reconnect" text present on the page.

Evidence: `screenshots/01-gbp-accounts-page.png`

### Scenario 2: Location list UI — single flat list, no account tabs

**Status:** pass

No `[data-role='account-tab']` or `[data-role='account-switcher']` elements found. The page renders 8 locations in a flat list using `[data-role='account-list']` with checkbox inputs (`[data-role='account-checkbox']`). Locations span 4 different Google Business accounts, all merged into a single list.

Evidence: `screenshots/01-gbp-accounts-page.png`

### Scenario 3: Location row fields — account name, title, address, store code

**Status:** pass

All expected data-role attributes present:
- 8 `[data-role='location-title']` elements (e.g. "Tidewater Firewood", "UserDocs", "Desert First Cleaning")
- 8 `[data-role='location-account-name']` elements showing account IDs across 4 accounts
- 3 `[data-role='location-address']` elements (shown when address data exists)
- 2 `[data-role='location-store-code']` elements (shown when store code exists)

### Scenario 4: Save selection and success confirmation

**Status:** pass

Checked "Tidewater Firewood" (already had "Desert First Cleaning" pre-checked). Clicked "Save Selection". Flash message displayed: "2 location(s) saved successfully." Redirected to `/integrations/connect/google_business` showing both saved location IDs.

Evidence: `screenshots/04-gbp-save-selection.png`, `screenshots/05-gbp-save-confirmed.png`

### Scenario 5: Update location selection without re-authenticating

**Status:** pass

Navigated back to `/integrations/connect/google_business/accounts` — no OAuth redirect, URL stayed on the accounts page. Previously saved locations were pre-checked. Unchecked "Tidewater Firewood", checked "Montpelier Firewood", saved. Flash: "2 location(s) saved successfully." with updated location IDs. No re-authentication required.

Evidence: `screenshots/06-gbp-update-selection.png`

### Scenario 6: Missing/deleted location flagging

**Status:** pass

Added `accounts/123/locations/deleted-loc-1` to `included_locations` in provider_metadata via psql. Navigated to accounts page. Warning banner displayed: "Previously configured location(s) are no longer available:" with `accounts/123/locations/deleted-loc-1` listed. `[data-role='missing-location']` and `[data-role='location-unavailable']` elements present.

Evidence: `screenshots/07-gbp-missing-location-flag.png`

### Scenario 7: Unauthenticated access redirect

**Status:** pass

Cleared cookies, navigated to `/integrations/connect/google_business/accounts`. Redirected to `/users/log-in`.

Evidence: `screenshots/08-gbp-unauthenticated-redirect.png`

### Scenario 8: Integrations page shows google_business integration

**Status:** pass

Logged back in, navigated to `/integrations`. "Google Business" listed with "Connected" badge, description "Business profile locations and reviews", and "Sync Now" / "Edit Accounts" buttons.

Evidence: `screenshots/09-gbp-integrations-list.png`

### Scenario 9: Connect grid includes google_business provider

**Status:** pass

Navigated to `/integrations/connect`. "Google Business" card present in the provider grid with "Connected" badge and "Reconnect" button. Card shows description "Business profile locations and reviews."

Evidence: `screenshots/10-gbp-connect-grid.png`

## Evidence

- `screenshots/00-integrations-landing.png` — initial integrations page after login
- `screenshots/01-gbp-accounts-page.png` — full-page location list with 8 locations across 4 accounts
- `screenshots/04-gbp-save-selection.png` — two locations checked before save
- `screenshots/05-gbp-save-confirmed.png` — success flash after saving 2 locations
- `screenshots/06-gbp-update-selection.png` — updated selection saved successfully
- `screenshots/07-gbp-missing-location-flag.png` — warning banner for deleted location
- `screenshots/08-gbp-unauthenticated-redirect.png` — redirect to login page
- `screenshots/09-gbp-integrations-list.png` — Google Business visible in integrations list
- `screenshots/10-gbp-connect-grid.png` — Google Business card in connect grid

## Issues

### Sandbox blocks GBP API calls in development

#### Severity
INFO

#### Scope
QA

#### Description
When the Phoenix server is started within the Claude Code sandbox, outbound HTTP requests to `mybusinessbusinessinformation.googleapis.com` are blocked (error: "non-existing domain"). The `mybusinessaccountmanagement.googleapis.com` domain is in the sandbox allowlist but the business information API domain is not. The server must be started with sandbox disabled for GBP location fetching to work. This only affects QA tooling — production and manual development are unaffected.

### Account names show raw numeric IDs instead of human-readable names

#### Severity
LOW

#### Description
Location rows display account names as raw account IDs (e.g. "Account 102071280510983396749") rather than human-readable account names. The `derive_account_name/1` function in `GoogleBusinessLocations` only strips the "accounts/" prefix and prepends "Account". The Google Account Management API returns an `accountName` field that could be used for friendlier display.
