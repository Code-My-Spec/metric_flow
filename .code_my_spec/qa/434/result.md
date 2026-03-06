# QA Result — Story 434: Connect Marketing Platform via OAuth

**Status:** fail

**Tested:** 2026-03-05
**Tester:** QA Agent (claude-sonnet-4-6)
**App URL:** http://localhost:4070
**Auth:** qa@example.com / hello world!

---

## Scenarios

### Scenario 1 — Platform selection page lists all supported platforms

**Result: pass**

Navigated to `/integrations/connect`. The page rendered the "Connect a Platform" heading and a grid of platform cards. All three required platforms were present with correct `data-platform` attributes:

- `data-platform="google_ads"` — "Google Ads" visible
- `data-platform="facebook_ads"` — "Facebook Ads" visible
- `data-platform="google_analytics"` — "Google Analytics" visible

Each card had a "Not connected" badge and a button with `data-role="connect-button"`.

Note: A fifth card with `data-platform="unsupported_platform"` labeled "Unsupported Platform" was also rendered in the grid (see Issue 1).

**Evidence:** `.code_my_spec/qa/434/screenshots/s1_platform_selection.png`, `.code_my_spec/qa/434/screenshots/s1_platform_selection_full.png`

---

### Scenario 2 — Connect buttons present for each platform, no re-authenticate text

**Result: pass**

On the platform selection grid:
- `[data-platform='google_ads'] [data-role='connect-button']` — present
- `[data-platform='facebook_ads'] [data-role='connect-button']` — present
- `[data-platform='google_analytics'] [data-role='connect-button']` — present
- "Re-authenticate" text — absent
- "Re-connect" text — absent

All five visible platform cards had a `[data-role='connect-button']` element.

**Evidence:** `.code_my_spec/qa/434/screenshots/s1_platform_selection.png`

---

### Scenario 3 — Per-platform detail view shows OAuth link that opens in a new tab

**Result: fail**

Navigated to `/integrations/connect/google_ads`. The detail card rendered correctly with the "Google Ads" heading, "Not connected" badge, and descriptive text. However, `[data-role='oauth-connect-button']` was **not present**. The page fell back to rendering a `phx-click="connect"` button (`[data-role='connect-button']`) instead of the OAuth anchor link.

Root cause: `handle_provider_params/2` calls `Integrations.authorize_url(:google_ads)` which returns `{:error, ...}` because no real provider credentials are configured in the development environment. When `@authorize_url` is nil, the template renders the phx-click button branch rather than the `<a target="_blank">` OAuth link. The `target="_blank"` behavior (opening in a new tab) could not be verified.

The spec requires: "If not connected: an OAuth initiation anchor tag rendered as `.btn .btn-primary` with `data-role='oauth-connect-button'` pointing to the authorize URL, opening in a new tab via `target='_blank'`."

**Evidence:** `.code_my_spec/qa/434/screenshots/s3_google_ads_detail.png`

---

### Scenario 4 — Detail page does not show re-authentication options

**Result: pass**

On `/integrations/connect/google_ads`:
- "Re-authenticate" — absent
- "Re-connect" — absent
- Page shows "Google Ads", "Not connected", and a "Connect Google Ads" button

**Evidence:** `.code_my_spec/qa/434/screenshots/s3_google_ads_detail.png`

---

### Scenario 5 — Account selection page renders correctly for Google Ads and Google Analytics

**Result: pass**

Navigated to `/integrations/connect/google_ads/accounts`:
- Page heading: "Google Ads — Select Accounts"
- `[data-role='account-list']` — present
- `[data-role='account-selection']` — present
- `input[type='checkbox'][data-role='account-checkbox']` — present, checked by default ("All accounts")
- `[data-role='save-selection']` button labeled "Save Selection" — present
- "Back" link to `/integrations/connect/google_ads` — present

Navigated to `/integrations/connect/google_analytics/accounts`:
- Page heading: "Google Analytics — Select Accounts"
- Same account-selection UI with checkbox and "Save Selection" button — present

**Evidence:** `.code_my_spec/qa/434/screenshots/s5_account_selection_google_ads.png`, `.code_my_spec/qa/434/screenshots/s5_account_selection_google_analytics.png`

---

### Scenario 6 — Integration not saved or shown as active before OAuth completes

**Result: pass**

On `/integrations/connect/google_ads` before any OAuth:
- "Integration saved" — absent
- "Integration active" — absent
- "Integration Active" — absent
- A connect option is present (`[data-role='connect-button']` with text "Connect Google Ads")

**Evidence:** `.code_my_spec/qa/434/screenshots/s3_google_ads_detail.png`

---

### Scenario 7 — OAuth callback with code parameter renders a result page (not blank)

**Result: pass (with notes)**

Navigated to `/integrations/oauth/callback/google_ads?code=test_auth_code&state=test_state`. The callback LiveView mounted and processed the request. As expected for a dev environment without real provider credentials, `Integrations.handle_callback/4` returned an error and the page rendered the error state:

- Heading "Connection Failed" — present
- Provider name "Google Ads" — present
- Error message "Could not complete the connection. Please try again." — present
- "Try again" link to `/integrations/connect/google_ads` — present
- "Back to integrations" link to `/integrations` — present
- "Integration saved" — absent
- "successfully connected" — absent

The callback view handles the error case correctly. The success path (`status: :connected`) rendering "Integration Active" / "Active" badge / "Your [Platform] account is connected and ready to sync data." could not be exercised without real OAuth credentials.

**Evidence:** `.code_my_spec/qa/434/screenshots/s7_callback_error_state.png`

---

### Scenario 8 — OAuth callback with `error=access_denied` shows clear error message

**Result: pass**

Navigated to `/integrations/oauth/callback/google_ads?error=access_denied`:
- Heading "Connection Failed" — present (in `text-error`)
- Error message "Access was denied" — present
- "Integration saved" — absent
- "successfully connected" — absent
- "Try again" link pointing to `/integrations/connect/google_ads` — present
- "Back to integrations" link — present

Navigated to `/integrations/oauth/callback/google_ads?error=access_denied&error_description=User+denied+access`:
- Same output as above — "Access was denied" (description ignored per `translate_oauth_error/2` design)
- Recovery links present

**Evidence:** `.code_my_spec/qa/434/screenshots/s8_callback_access_denied.png`

---

### Scenario 9 — Unauthenticated user is redirected

**Result: pass**

Verified via `curl` (no session cookie):

```
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:4070/integrations/connect
```

Response: `302 http://localhost:4070/users/log-in`

Unauthenticated requests to `/integrations/connect` are redirected to the login page.

---

### Scenario 10 — Integrations pages are account-scoped and contain no transfer language

**Result: pass (with notes)**

Navigated to `/integrations` as `qa@example.com`:
- Page shows "Integrations" heading and "Manage your connected marketing platforms" subtitle
- "No platforms connected yet" state with "Connect your first platform" CTA — correct for a fresh account
- "Available Platforms" section shows "Google" (the only configured provider in dev)
- "Transfer to agency" — absent
- "Assign to agency" — absent
- "Move to agency" — absent

Navigated to `/integrations/connect/google_ads`:
- "Transfer to agency" — absent
- "Assign to agency" — absent
- "Move to agency" — absent
- Page is scoped to the current user's session

Note: The "Available Platforms" section on `/integrations` only lists "Google" because `IntegrationLive.Index.build_platform_list/0` calls only `Integrations.list_providers()` without the canonical-platform fallback used by `IntegrationLive.Connect`. See Issue 2.

**Evidence:** `.code_my_spec/qa/434/screenshots/s10_integrations_list.png`, `.code_my_spec/qa/434/screenshots/s10_integrations_list_full.png`, `.code_my_spec/qa/434/screenshots/s10_connect_detail_no_transfer.png`

---

## Evidence

| Screenshot | Description |
|---|---|
| `screenshots/s1_platform_selection.png` | Platform selection grid — all three platforms visible with connect buttons |
| `screenshots/s1_platform_selection_full.png` | Full-page view of platform selection including Unsupported Platform card |
| `screenshots/s3_google_ads_detail.png` | Google Ads detail view — fallback connect button rendered, no oauth-connect-button |
| `screenshots/s5_account_selection_google_ads.png` | Account selection page for Google Ads with checkbox and Save Selection button |
| `screenshots/s5_account_selection_google_analytics.png` | Account selection page for Google Analytics |
| `screenshots/s7_callback_error_state.png` | OAuth callback with code parameter — error state rendered (no dev credentials) |
| `screenshots/s8_callback_access_denied.png` | OAuth callback with error=access_denied — "Access was denied" error with Try again link |
| `screenshots/s10_integrations_list.png` | Integrations index — shows only "Google" in Available Platforms, not the full canonical list |
| `screenshots/s10_integrations_list_full.png` | Full-page integrations index |
| `screenshots/s10_connect_detail_no_transfer.png` | Connect detail page — no transfer language present |

---

## Issues

### Issue 1

**Severity:** MEDIUM
**Scope:** app
**Title:** "Unsupported Platform" card is visible to end users on the platform selection page

**Description:** The platform selection grid at `/integrations/connect` includes a card labeled "Unsupported Platform" with description "This integration is not yet available" and a "Connect" button. This platform entry is part of the `@canonical_platforms` list in `IntegrationLive.Connect` with key `:unsupported_platform`. Clicking the Connect button would trigger the `connect` event with `provider="unsupported_platform"`, which would fail with the flash message "This platform is not yet supported."

The card is confusing to end users — it looks like a real platform that is coming soon, but clicking Connect produces an error. The `@canonical_platforms` list was likely intended as a development/testing fixture and should not include the `:unsupported_platform` entry in production, or the card should be hidden from the UI.

**Reproduction:**
1. Log in as any user
2. Navigate to `/integrations/connect`
3. Observe the "Unsupported Platform" card in the grid alongside Google Ads, Facebook Ads, Google Analytics

**File:** `lib/metric_flow_web/live/integration_live/connect.ex` — `@canonical_platforms` list, line 32–37

---

### Issue 2

**Severity:** MEDIUM
**Scope:** app
**Title:** Integrations index page (`/integrations`) only shows configured providers, missing canonical marketing platforms

**Description:** The "Available Platforms" section on `/integrations` calls `Integrations.list_providers()` to build the platform list. In the dev environment (and any environment where Google Ads, Facebook Ads, and Google Analytics OAuth credentials are not configured), only the configured providers appear — in dev, only "Google". The three canonical marketing platforms (Google Ads, Facebook Ads, Google Analytics) are missing from the Available Platforms grid.

By contrast, `/integrations/connect` correctly uses a canonical-platform fallback in `build_platform_list/1` that always includes Google Ads, Facebook Ads, and Google Analytics regardless of configured providers.

The root cause is that `IntegrationLive.Index.build_platform_list/0` (line 341) does not apply the same canonical-platform union logic that `IntegrationLive.Connect.build_platform_list/1` does.

**Reproduction:**
1. Log in as any user with no integrations connected
2. Navigate to `/integrations`
3. Observe "Available Platforms" section — only "Google" is shown
4. Navigate to `/integrations/connect`
5. Observe Google Ads, Facebook Ads, Google Analytics are all shown

**File:** `lib/metric_flow_web/live/integration_live/index.ex` — `build_platform_list/0`, line 341–354

---

### Issue 3

**Severity:** LOW
**Scope:** app
**Title:** Per-platform detail view does not render OAuth link (`data-role="oauth-connect-button"`) when provider credentials are not configured

**Description:** The spec states the per-platform detail view at `/integrations/connect/:provider` should show an OAuth initiation anchor with `data-role="oauth-connect-button"` and `target="_blank"`. This element is conditionally rendered only when `@authorize_url` is non-nil. When `Integrations.authorize_url/1` returns an error (no provider credentials configured), the view falls back to a `phx-click="connect"` button. This fallback button clicks the LiveView event which also calls `authorize_url`, and would show a flash error "This platform is not yet supported" or "Could not initiate connection."

This means in the dev/staging environment, the per-platform detail view does not demonstrate the correct OAuth link behavior described in the spec and BDD criteria 4017. The `target="_blank"` new-tab behavior cannot be verified without real provider credentials.

This may be acceptable in dev, but the QA test cannot confirm the correct production behavior for criterion 4017.

**Reproduction:**
1. Navigate to `/integrations/connect/google_ads`
2. Inspect the DOM — `[data-role='oauth-connect-button']` is absent
3. Instead, `[data-role='connect-button']` with `phx-click="connect"` is present

**File:** `lib/metric_flow_web/live/integration_live/connect.ex` — `render_platform_detail/1`, lines 143–153
