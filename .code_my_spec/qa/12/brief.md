# Qa Story Brief

Story 12: Connect Financial Platform via OAuth (QuickBooks)

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

`qa@example.com` owns the only existing QuickBooks integration (id 58, realm `9130355098863166`) on this checkout.

## Seeds

No real Intuit sandbox *login* credentials are available in this environment (only the OAuth app's own `QUICKBOOKS_CLIENT_ID`/`SECRET` in `.env.dev`) — a genuinely fresh, full consent-screen round trip to Intuit cannot be completed headlessly. This mirrors story 42's QA finding: the one existing QuickBooks integration (id 58) has an expired, unrefreshable token (`expires_at` 2026-04-05, well past this environment's wall clock). Test what's reachable without real Intuit consent: OAuth initiation (redirect URL), abandoned-flow non-persistence, simulated callback error paths (via direct navigation to the callback URL with `?error=...`, which doesn't require a real Intuit round trip), the account-selection UI/mechanism, and the connected-confirmation/financial-metric pieces via the existing integration plus direct code reading.

## What To Test

- **85/913 — User can initiate OAuth flow.** Navigate to `/app/integrations/connect`, find the QuickBooks "Connect" button, and confirm clicking it redirects (via `/app/integrations/oauth/quickbooks`) toward a real `https://appcenter.intuit.com` or `https://oauth.platform.intuit.com` authorization URL (checked via `browser_get_url` after the redirect, without completing the real consent form).
- **89/917, 918 — Integration saved only after OAuth completes; abandoned flow saves nothing.** Confirm via code (`IntegrationOauthController.callback/2` is the only insertion point — `Integrations.handle_callback/4`) that no DB row is touched during `request/2`. Live-confirm by querying the `integrations` table for QuickBooks before and after merely visiting the connect page / redirect step without completing consent — count should be unchanged.
- **91/920 — Failed OAuth attempt shows a clear error.** As a logged-in user, navigate directly to `/app/integrations/oauth/callback/quickbooks?error=access_denied` (simulating the provider's own redirect on a declined consent, which doesn't require real Intuit credentials since the controller branches on `params["error"]` before ever calling the provider). Confirm the connect page shows the "Connection Failed" state with a clear message ("Access was denied...").
- **87/915 — User selects income accounts after authenticating.** Navigate to `/app/integrations/connect/quickbooks/accounts` using the existing (expired) integration. Confirm the account-selection form (`[data-role='account-selection']`) renders; since the live API call will fail (expired token), confirm a manual entry fallback is available and that submitting a manual account ID persists (`Integrations.update_provider_metadata`) and redirects back to the provider detail page with a success flash.
- **88/916 — Selecting multiple income accounts sums their debits and credits.** Read `connect.ex`'s `save_account_selection`/`render_account_selection`: confirm whether QuickBooks actually renders checkboxes (multi-select, like `:google_business`) or radio buttons (single-select). Cross-check `metadata_key_for_provider(:quickbooks)` (singular `income_account_id`, not an array key) and `DataProviders.QuickBooks.resolve_account_id/2` (reads a single `income_account_id` string, queries the TransactionList report for exactly one `account` param). If the UI is genuinely single-select and the sync layer genuinely only ever queries one account, this criterion's own feature doesn't exist — confirm by inspection rather than assuming, and check whether its BDD spex actually tests multi-selection or just generic form presence.
- **90/919 — User sees confirmation that QuickBooks is connected.** Read `render_result/1`'s `:connected` branch (checkmark, "Integration Active", "ready to sync data", Active badge) — confirm this is reachable by simulating the `info: "Successfully connected!"` flash path (can be triggered by visiting `/app/integrations/connect/quickbooks?` with that flash set, or accepted via code read if not easily reachable without a real callback).
- **92/921 — Financial data appears as a metric for correlation.** Query the `metrics` table directly for `QUICKBOOKS_ACCOUNT_DAILY_CREDITS`/`_DEBITS` rows tied to integration 58 (already confirmed populated by story 42's QA pass) — confirm these are ordinary rows with no special-casing that would exclude them from the correlation engine (cross-check against story 24/25's correlation QA, which already exercised cross-platform metrics generally).

## Result Path

`.code_my_spec/qa/12/result.md`

## Setup Notes

Results are recorded via `submit_qa_result` plus `create_issue` — there is no `result.md` file in practice.

## Results

- **85/913**: pass. Clicking Connect for QuickBooks on `/app/integrations/connect` redirects via `/app/integrations/oauth/quickbooks` to a real `https://accounts.intuit.com/app/sign-in?redirect_uri=...appcenter.intuit.com...client_id=AB3nq...&scope=com.intuit.quickbooks.accounting&state=...` URL -- genuine OAuth initiation, correct scope and state.
- **89/917, 918**: pass. Confirmed via DB: the `integrations` table's single QuickBooks row (id 58) was unchanged in count before and after initiating/abandoning the flow -- `IntegrationOauthController.callback/2` is the only insertion point, never reached without a real provider round trip.
- **91/920**: pass. Navigating directly to `/app/integrations/oauth/callback/quickbooks?error=access_denied` (simulating the provider's own declined-consent redirect) shows "Connection Failed -- Access was denied. Please try again if you want to connect." live.
- **87/915**: pass. Temporarily bumped integration 58's `expires_at` into the future (explicitly in UTC -- a naive `now() + interval` wrote local wall-clock time that was still read back as expired, the same skew pattern seen elsewhere this session) to get past the (correct) expired-token guard, confirmed the manual Company ID entry form renders and that submitting it saves and redirects back to the provider page. Reverted `expires_at` to its genuine value afterward.
- **88/916**: **fail**. Confirmed live and in code: QuickBooks account selection is a single plain text input (`manual_property_id`), not a multi-select -- no checkboxes exist for this provider (contrast with `:google_business`, which genuinely supports `location_ids[]`). The sync layer (`DataProviders.QuickBooks.resolve_account_id/2`) only ever reads one `income_account_id` and queries one `account` param. There is no code path for selecting or summing across multiple income accounts. Filed as issue `054abcc0` (high).
- **92/921**: pass. `QUICKBOOKS_ACCOUNT_DAILY_CREDITS`/`_DEBITS` have 1098 rows each in the `metrics` table tied to this integration, ordinary metric rows with no special-casing that would exclude them from correlation (consistent with story 24/25's correlation QA this session, which already exercises cross-platform metrics generally).
- **86/914, 90/919**: pass via code review -- the existing integration (id 58, real access/refresh tokens and realm_id) is itself proof OAuth completed and granted access previously; `render_result/1`'s `:connected` branch (checkmark, "Integration Active", "ready to sync data", Active badge) is reachable whenever the controller sets `flash: {info: "Successfully connected!"}`, which only happens after `Integrations.handle_callback/4` returns `{:ok, integration}`. Not independently re-exercised live since no fresh consent round trip was available in this environment (no real Intuit sandbox login credentials, only the OAuth app's own client id/secret).

Submitting as **partial** with issue `054abcc0` linked.

## Retest 2026-10-01

Fix for issue `054abcc0` (commits `04b5af1`, `bb3ddbb`) confirmed both at the unit level and live:

- `mix test test/metric_flow/data_sync/data_providers/quick_books_test.exs test/metric_flow_web/live/integration_live/connect_test.exs` -- 48/48 passed, including the dedicated cross-account summing test (750+300=1050 combined credits).
- Live: bumped integration 58's expiry into the future (UTC) to reach `/app/integrations/connect/quickbooks/accounts`. Confirmed genuine `<input type="checkbox" name="income_account_ids[]">` elements now render (previously a single plain text input). Set the saved selection to two accounts (`["212", "99"]`) via SQL and reloaded: both rendered as separate, correctly pre-checked checkboxes. Unchecked one and saved: DB confirmed `income_account_ids` correctly reduced to `["212"]` only (a direct replace, not a merge) -- an initial attempt at this looked like it hadn't taken effect, but re-checking the checkbox's own state before/after the click showed that was a transient browser-automation glitch, not a real bug; the retry behaved correctly.
- Noted a stale, now-inaccurate comment in `connect.ex`'s `save_quickbooks_multi_selection/5` claiming "sync still only reads the legacy singular key" -- `quick_books.ex`'s `resolve_account_ids/2` was updated in the second commit to read the plural `income_account_ids` key, so this comment is leftover from before that commit landed. Doesn't affect behavior (purely a stale comment), not filed as a separate issue.
- Reverted integration 58 back to its original clean single-account state (`income_account_id: "212"`, no `income_account_ids` key, `expires_at` restored) afterward.

88/916 now: **pass**. All other criteria (85/913 through 92/921) were already verified passing in the prior attempt and are unaffected by this fix. Submitting as pass.
