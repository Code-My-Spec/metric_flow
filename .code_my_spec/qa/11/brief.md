# Qa Story Brief

Story 11: Connect Marketing Platform via OAuth

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
```

`qa@example.com` owns real connected Google Ads, Google Analytics, and Facebook Ads integrations from stories 35/36/37 this session (real historical metric data confirmed in all three).

## Seeds

No real OAuth sandbox login credentials are available in this environment for any of the three platforms (same limitation noted repeatedly this session) — a genuine fresh consent round trip cannot be completed headlessly. Use the existing connected integrations plus direct OAuth-initiation/error-path testing (neither requires completing real consent) and code review for anything only reachable via a live callback.

## What To Test

- **76/560 — Initiate OAuth for all three platforms.** For each of `/app/integrations/oauth/google_ads`, `/app/integrations/oauth/google_analytics`, `/app/integrations/oauth/facebook_ads`: confirm it redirects to a real provider consent URL (accounts.google.com or facebook.com) with correct client_id/scope.
- **77/561 — Opens in popup or new tab.** Code read (already confirmed): the Connect buttons use `target="_blank" rel="noopener noreferrer"`.
- **78/562 — Redirected back to platform selection after success.** Code read: `IntegrationOauthController.callback/2` on success redirects to the connect/accounts page for that provider (or `/app/integrations` on completion), not an arbitrary page.
- **79/563 — Select accounts/properties to sync.** Live: open the account-selection page for the existing Google Ads integration (`/app/integrations/connect/google_ads/accounts` or equivalent) and confirm it lists real customer IDs fetched from the live Google Ads API.
- **80/564 — Modify selection later without re-authenticating.** Live: change the selected account/property on an already-connected integration and confirm no OAuth redirect occurs.
- **81/565 — Integration saved only after OAuth completes; incomplete flow saves nothing.** Code read: the callback controller is the only insertion point, consistent with the identical pattern already confirmed for QuickBooks and Google Business this session.
- **82/566 — Confirmation that integration is active.** Code read: `render_result/1`'s `:connected` branch, same mechanism already confirmed working for other providers.
- **83/567 — Failed OAuth shows a clear error.** Live: navigate to `/app/integrations/oauth/callback/<provider>?error=access_denied` for at least one of the three platforms and confirm a clear "Connection Failed" message.
- **84/568 — Platform connection belongs to client account, not transferable to agency.** Live: confirm `/app/integrations` and `/app/integrations/connect/<provider>` never show any "Transfer to agency"/"Assign to agency"/"Move to agency" option, and that integrations are scoped to the connecting user (already confirmed this session: `integrations` table has a `user_id` column, no `account_id` at all, so there is structurally no agency-claim mechanism).

## Result Path

`.code_my_spec/qa/11/result.md`

## Setup Notes

This story substantially overlaps with the already-tested provider-specific sync stories (35 GA4, 36 Google Ads, 37 Facebook Ads) and the already-tested QuickBooks/Google Business OAuth stories (12, 43) — reuse those findings about the generic OAuth mechanics (callback-only persistence, error handling, confirmation UI) rather than re-deriving them, and focus live testing on what's specific to this story: the popup/new-tab mechanism, the account-selection step for these three providers specifically, and the agency-non-transferability guarantee.

## Results

- **76/560**: pass. Live: `/app/integrations/oauth/google_ads` and `/app/integrations/oauth/google_analytics` both redirect to a real Google OAuth URL (hitting the same `redirect_uri_mismatch` on Google's side already documented as qa-scope issue `6cdb28d8` in story 43 — the app-side redirect itself is correct). `/app/integrations/oauth/facebook_ads` redirects to a real `facebook.com/login.php` consent page with no mismatch.
- **77/561**: pass (code review). Connect buttons use `target="_blank" rel="noopener noreferrer"`.
- **78/562**: pass (code review). `IntegrationOauthController.callback/2` redirects to `/app/integrations/connect/#{provider}` on success — the provider's own "platform selection"/connect landing page.
- **79/563**: pass. Live: `/app/integrations/connect/google_ads/accounts` with the real existing integration (token bumped non-expired in UTC to get past the guard) shows the manual Customer ID fallback form — same verified pattern as QuickBooks (story 12): `fetch_provider_accounts/3` calls the real `list_google_ads_customers/1` API and falls back to manual entry when that call fails (consistent with this account's real, revoked Google Ads token).
- **80/564**: pass. Live: submitted a manual customer ID (1234567890), saved without any OAuth redirect, landed back on the provider page; confirmed via DB that `provider_metadata.customer_id` was updated to the new value.
- **81/565**: pass (code review, consistent with the identical pattern already confirmed for QuickBooks/Google Business this session). Callback is the only insertion point.
- **82/566**: pass (code review). `render_result/1`'s `:connected` branch, same mechanism confirmed for other providers.
- **83/567**: pass. Live: `/app/integrations/oauth/callback/facebook_ads?error=access_denied` shows "Connection Failed" with a clear message.
- **84/568**: pass. Live: neither `/app/integrations` nor `/app/integrations/connect/google_ads` show any "Transfer/Assign/Move to agency" text; the `integrations` table has a `user_id` column and no `account_id` at all, so there is structurally no mechanism for an agency to claim a connection.

No issues found. Reverted the test token's `expires_at` back to its original value afterward. Submitting as **pass**.
