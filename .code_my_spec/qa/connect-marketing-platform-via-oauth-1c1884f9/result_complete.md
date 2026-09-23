# QA Result

Story 434: Connect Marketing Platform via OAuth

## Status

pass

## Scenarios

### Scenario 1 — Platform selection page lists all supported providers

pass

Navigated to `http://localhost:4070/integrations/connect`. The page rendered with heading "Connect a Provider". Three provider cards were found in the grid:

- `[data-platform="facebook_ads"]` — shows "Facebook" and "Facebook and Instagram advertising"
- `[data-platform="google"]` — shows "Google" and "Google Ads and Google Analytics"
- `[data-platform="quickbooks"]` — shows "QuickBooks" and "Financial accounting and bookkeeping"

No "Re-authenticate" text appeared on the page. Facebook and Google cards showed "Connected" badges (integrations already set up in QA account) and "Reconnect" buttons. QuickBooks showed "Not connected" badge and "Connect" button. All three `[data-role='connect-button']` elements were confirmed present.

Screenshot: `.code_my_spec/qa/434/screenshots/01-platform-selection.png`

### Scenario 2 — Connect buttons are present for each provider

pass

On the same `/integrations/connect` page, each provider card contained a `[data-role='connect-button']` button. Confirmed using `browser_find` for each selector:

- `[data-platform='google'] [data-role='connect-button']` — present, text "Reconnect"
- `[data-platform='facebook_ads'] [data-role='connect-button']` — present, text "Reconnect"
- `[data-platform='quickbooks'] [data-role='connect-button']` — present, text "Connect"

Screenshot: `.code_my_spec/qa/434/screenshots/02-connect-buttons.png`

### Scenario 3 — Per-provider detail view shows OAuth initiation link

pass

Navigated to `/integrations/connect/google`. The page shows "Google" as the card title. The integration is connected (previously set up), so the `[data-role='oauth-connect-button']` link shows "Reconnect" (correct connected-state label per spec). The link has `target="_blank"` and its href is a valid Google OAuth URL starting with `https://accounts.google.com/o/oauth2/v2/auth?...`. "Back to integrations" link is present in the HTML (confirmed via `browser_get_html`).

Also navigated to `/integrations/connect/facebook_ads`. The page shows "Facebook" as the title with a `[data-role='oauth-connect-button']` link ("Reconnect") pointing to `https://www.facebook.com/v4.0/dialog/oauth?...`. Structure matches expectations.

Screenshots:
- `.code_my_spec/qa/434/screenshots/03-google-detail.png`
- `.code_my_spec/qa/434/screenshots/03b-facebook-detail.png`

### Scenario 4 — Detail view does not show re-authenticate option

pass

Navigated to `/integrations/connect/google`. Page text does not contain "Re-authenticate" or "Re-connect" (with hyphen). Page rendered without error. The button labels are "Reconnect" (one word, no hyphen) which is distinct from the disallowed "Re-connect". Scenario passes.

### Scenario 5 — Account selection page renders correctly

pass

Navigated to `/integrations/connect/google/accounts`. Google integration exists in QA account so the accounts page loaded directly. Confirmed:

- Page heading: "Google — Select Accounts"
- `[data-role='account-selection']` form element is present
- `[data-role='save-selection']` button labeled "Save Selection" is present
- `[data-role='manual-property-input']` input is present with placeholder "properties/123456789"
- Label shows "GA4 Property ID" (Google-specific)

Navigated to `/integrations/connect/facebook_ads/accounts`. Facebook integration exists in QA account so the accounts page loaded. Confirmed:

- Page heading: "Facebook — Select Accounts"
- Label shows "Ad Account ID" (NOT "GA4 Property ID" — correct, no cross-contamination)

Screenshots:
- `.code_my_spec/qa/434/screenshots/05-google-accounts.png`
- `.code_my_spec/qa/434/screenshots/05b-facebook-accounts.png`

### Scenario 6 — Integration not saved before OAuth completion

pass

Navigated to `/integrations/connect/google`. Since the QA owner account already has a google integration, the page shows the connected detail view (not the result view). Confirmed that "Integration saved", "Integration active", and "successfully connected" text do not appear on the page. The `[data-role='oauth-connect-button']` is present (labeled "Reconnect" since connected). The result view with "Integration Active" heading only appears when redirected from the OAuth callback with a success flash, not on direct navigation.

Screenshot: `.code_my_spec/qa/434/screenshots/06-not-saved-before-oauth.png`

### Scenario 7 — OAuth callback error result view

pass

Visited `/integrations/oauth/callback/google?error=access_denied`. The controller processed the error and redirected to `/integrations/connect/google` with an error flash. The LiveView detected the flash and rendered the `:result` view with `result_status: :error`. Confirmed:

- Page redirected to `http://localhost:4070/integrations/connect/google`
- "Connection Failed" heading is present
- Error message "Access was denied. Please try again if you want to connect." is visible
- "Try again" link is present
- "Back to integrations" link is present
- "Integration saved" and "successfully connected" do NOT appear

Screenshot: `.code_my_spec/qa/434/screenshots/07-callback-error-result.png`

### Scenario 8 — Error callback with error_description

pass

Visited `/integrations/oauth/callback/google?error=access_denied&error_description=User+denied+access`. The error result view rendered with "Connection Failed" heading and error message visible. The specific `error_description` value ("User denied access") is not displayed verbatim — the controller uses a generic "Access was denied" message. This is acceptable behavior; the user sees a clear error message.

Screenshot: `.code_my_spec/qa/434/screenshots/08-access-denied-error.png`

### Scenario 9 — Unauthenticated user is redirected

pass

Two methods confirmed redirect:

1. `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/integrations/connect` returned `302`
2. Fresh browser session (no cookies) navigated to `http://localhost:4070/integrations/connect` and was redirected to `http://localhost:4070/users/log-in`

Screenshot: `.code_my_spec/qa/434/screenshots/09-unauthenticated-redirect.png`

### Scenario 10 — Integration page is scoped to logged-in account

pass

Logged in as `qa@example.com` and navigated to `/integrations`. Page rendered showing only QA Test Account integrations (Google Analytics, Google Ads, Facebook Ads connected; QuickBooks not connected). No "Transfer to agency", "Assign to agency", or "Move to agency" text appeared.

Navigated to `/integrations/connect/google`. Page showed "Connect a Provider" heading and "Google" card with connected state. No transfer options appeared. Content correctly shows "Connect" and "Google".

Screenshot: `.code_my_spec/qa/434/screenshots/10-integrations-scoped.png`

## Evidence

- `.code_my_spec/qa/434/screenshots/01-platform-selection.png` — Provider selection grid with all three providers
- `.code_my_spec/qa/434/screenshots/02-connect-buttons.png` — All three connect buttons visible
- `.code_my_spec/qa/434/screenshots/03-google-detail.png` — Google provider detail with OAuth link and connected state
- `.code_my_spec/qa/434/screenshots/03b-facebook-detail.png` — Facebook provider detail with OAuth link and connected state
- `.code_my_spec/qa/434/screenshots/05-google-accounts.png` — Google account selection page with GA4 Property ID input
- `.code_my_spec/qa/434/screenshots/05b-facebook-accounts.png` — Facebook account selection page with Ad Account ID input
- `.code_my_spec/qa/434/screenshots/06-not-saved-before-oauth.png` — Google detail view showing connected state, no result view
- `.code_my_spec/qa/434/screenshots/07-callback-error-result.png` — Connection Failed result view after access_denied callback
- `.code_my_spec/qa/434/screenshots/08-access-denied-error.png` — Connection Failed result view with error_description callback
- `.code_my_spec/qa/434/screenshots/09-unauthenticated-redirect.png` — Login page after unauthenticated redirect
- `.code_my_spec/qa/434/screenshots/10-integrations-scoped.png` — Integrations list scoped to QA account

## Issues

### OAuth callback does not display error_description from provider

#### Severity
LOW

#### Description
When visiting `/integrations/oauth/callback/google?error=access_denied&error_description=User+denied+access`, the error result view shows a generic message "Access was denied. Please try again if you want to connect." rather than the provider's human-readable `error_description` value ("User denied access"). The `error_description` parameter is passed by OAuth providers to give users a specific explanation of why the connection failed. Ignoring it in favor of a generic message may be less helpful in cases where providers return distinct error reasons (e.g., "Account suspended", "Scope not approved").

This is a minor UX gap, not a functional failure. The user still sees a clear error state and "Try again" link.
