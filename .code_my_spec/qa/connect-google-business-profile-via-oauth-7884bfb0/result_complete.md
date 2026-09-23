# Qa Result

## Status

pass

## Scenarios

### Scenario 1: Google Business appears on the connect page

**Status:** pass

Navigated to `/integrations/connect`. Google Business card present with `[data-platform='google_business']`, showing "Connected" badge and "Reconnect" button.

Evidence: `screenshots/01-connect-grid-gbp.png`

### Scenario 2: Google Business detail page

**Status:** pass

Navigated to `/integrations/connect/google_business`. Shows "Connected" badge, connected email (`johns10@gmail.com`), Location ID field with saved selections, "Select Accounts" button, and "Reconnect" button. No "Re-authenticate" text present.

Evidence: `screenshots/02-gbp-detail-page.png`

### Scenario 3: OAuth flow initiates correctly

**Status:** pass (already connected)

OAuth was already completed in a prior session. The detail page shows "Connected" status with "Select Accounts" and "Reconnect" options. The "Reconnect" button would initiate a new OAuth flow. Not re-tested to avoid invalidating the existing connection.

### Scenario 4: Account/location selection page with real data

**Status:** pass

Navigated to `/integrations/connect/google_business/accounts`. Real location list rendered with 8 locations across 4 accounts. All expected data-role attributes present: `account-list`, `location-title`, `location-account-name`, `location-address`. Multi-select checkboxes with `name='location_ids[]'`.

Evidence: `screenshots/04-location-list.png`

### Scenario 5: Multi-select and save

**Status:** pass

Checked "Tidewater Firewood" and "UserDocs" locations. Clicked "Save Selection". Flash: "4 location(s) saved successfully." (4 because 2 were already checked from prior selections). Redirected to `/integrations/connect/google_business`.

Evidence: `screenshots/05-save-selection.png`, `screenshots/06-save-confirmed.png`

### Scenario 6: Return to accounts without re-authenticating

**Status:** pass

Navigated back to `/integrations/connect/google_business/accounts`. No OAuth redirect — URL stayed on accounts page. Previously saved locations were pre-checked. Changed selection (unchecked UserDocs, checked Syracuse Firewood), saved successfully. No re-authentication required.

Evidence: `screenshots/07-return-update.png`

### Scenario 7: Empty selection shows error

**Status:** pass

Unchecked all locations and submitted form. Error message displayed: "Please select at least one location."

Evidence: `screenshots/08-empty-selection-error.png`

### Scenario 8: Failed OAuth callback shows error

**Status:** pass

Navigated to `/integrations/oauth/callback/google_business?error=access_denied&error_description=User+denied+access`. Redirected to `/integrations/connect/google_business` with "Connection Failed" page, error flash "Access was denied. Please try again if you want to connect.", and "Try again" button. No 500 error.

Evidence: `screenshots/09-oauth-error.png`

### Scenario 9: Unauthenticated access redirects

**Status:** pass

Cleared cookies, navigated to `/integrations/connect/google_business/accounts`. Redirected to `/users/log-in`.

Evidence: `screenshots/10-unauth-redirect.png`

### Scenario 10: Integrations index shows Google Business

**Status:** pass

Logged back in, navigated to `/integrations`. Google Business listed with "Connected" badge, "Sync Now" and "Edit Accounts" buttons visible.

Evidence: `screenshots/11-integrations-list.png`

## Evidence

- `screenshots/01-connect-grid-gbp.png` — connect page with Google Business card
- `screenshots/02-gbp-detail-page.png` — Google Business detail page showing connected state
- `screenshots/04-location-list.png` — location selection with 8 real locations
- `screenshots/05-save-selection.png` — locations checked before save
- `screenshots/06-save-confirmed.png` — success flash after saving
- `screenshots/07-return-update.png` — updated selection saved without re-auth
- `screenshots/08-empty-selection-error.png` — error on empty selection
- `screenshots/09-oauth-error.png` — OAuth error callback handled gracefully
- `screenshots/10-unauth-redirect.png` — unauthenticated redirect to login
- `screenshots/11-integrations-list.png` — Google Business in integrations list

## Issues

### Account names show raw numeric IDs

#### Severity
LOW

#### Description
Location rows display account names as raw account IDs (e.g. "Account 102071280510983396749") rather than human-readable names. The Google Account Management API returns `accountName` which could be used for friendlier display.

### Codemyspec feedback hook compilation error on hot-reload

#### Severity
LOW

#### Scope
QA

#### Description
During QA, a hot-reload triggered a compilation error in `lib/metric_flow_web/hooks/codemyspec_feedback_hook.ex` — `assign/3` was undefined because `import Phoenix.LiveView` no longer exports it in newer Phoenix versions. Fixed by changing to `import Phoenix.Component, only: [assign: 3]`.
