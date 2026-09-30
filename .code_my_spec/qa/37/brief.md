# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server).

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_fill({ selector = "#login_form_password input[name='user[email]']", text = "qa@example.com" })
browser_fill({ selector = "#login_form_password input[name='user[password]']", text = "hello world!" })
browser_evaluate({ expression = "document.getElementById('login_form_password').requestSubmit()" })
```

## Seeds

Base seeds already in place (qa@example.com / hello world!). This account has a real, connected Facebook Ads integration (provider `facebook_ads`, ad_account_id `135910517`) whose token is already genuinely expired and non-refreshable, confirmed live in story 40's session ("Token expired and could not be refreshed. Please reconnect." appears naturally in Sync History on every daily-sync trigger) — directly usable for criterion 979 without any setup.

## What To Test

- **971** (fetches via Facebook Marketing API using Facebook's own separate OAuth): code review — `facebook_ads.ex` uses `integration.access_token`, calls `graph.facebook.com/v22.0/.../insights` directly, entirely independent of the Google integrations' token storage. Live: confirm the integration is listed as "Connected as ... via Facebook" on `/app/integrations`, distinct from the Google-connected ones.
- **972** (no ad account configured fails clearly, not silently skipped): temporarily clear `ad_account_id` from the real integration's `provider_metadata` via SQL, trigger the daily sync via `[data-role='trigger-daily-sync']` on `/app/integrations/sync-history` (same repro path used by this criterion's own spex and confirmed necessary in story 40 — the per-card Sync Now button disables itself client-side when no account is selected), confirm a `Failed` Facebook Ads entry appears with an error rather than nothing. Restore `ad_account_id` afterward.
- **973** (campaign-level by default, adset-level breakdown available): the sync-history page has a real "Sync Facebook Ads with ad-set-level breakdown (default: campaign-level)" checkbox (seen live in story 40's session) — confirm it exists and toggling it is reflected in `build_fields/1`'s `level` param via code review (`:adset` → `"adset"` level with `adset_name` field added).
- **974** (core metrics: impressions, clicks, spend, cpm, cpc, ctr, conversions, conversion_rate): after a successful sync with real data (use the account's historical sync results if the token issue blocks a fresh live sync), query the `metrics` table for `provider = 'facebook_ads'` and confirm all 8 metric names are present.
- **975/976** (548-day backfill on first sync, less if account has less history): code review — `default_date_range/0` computes `{today - 548, today - 1}`; `sync_worker.ex`'s `determine_date_range/3` passes `nil` for `:initial` syncs so the provider's own default applies. Same pattern already verified for GA4 (story 35) and Search Console (story 40) this session.
- **977** (pagination until all rows retrieved): code review — `fetch_next_page/7` follows `paging.cursors.after` recursively until no next cursor, accumulating across pages (`@page_limit` 100).
- **978** (non-numeric metric value stored as zero, not failing the sync): code review — `parse_integer/1` and `parse_float/1` both have a catch-all clause returning `0`/`0.0` for any non-numeric/unparseable input (nil, non-numeric string, etc.), so a malformed field can never crash `transform_row/2`.
- **979** (API rejects request — expired auth, insufficient permissions, unrecognized account, rate limit — fails with the API's error surfaced): live via the already-expired real integration's token failure ("Token expired and could not be refreshed. Please reconnect." in Sync History). Code review confirms the provider itself separately maps 401→`:unauthorized`, 403→`:insufficient_permissions`, 429→`:rate_limited`, and Facebook's OAuth error code 190→`:invalid_token`.
- **980** (automatic retry before marked failed, logged with enough detail, visible in Sync History): code review — `sync_worker.ex` uses `max_attempts: 3` via Oban.Worker (Oban's own exponential backoff applies between attempts), matching the sync-history page's own copy ("Failed syncs are automatically retried up to 3 times with exponential backoff"). Live: confirm the existing token-expiry failure is clearly visible in Sync History with a readable message. Not practical to observe the actual multi-attempt retry cycle live within a QA session (Oban's backoff spans minutes).

## Result Path

.code_my_spec/qa/37/result.md

## Setup Notes

Given the patterns already found in stories 35 (GA4) and 40 (Search Console) this session, checked whether `format_error/1` in `sync_worker.ex` has a clause for Facebook's provider-specific error atoms — it does not, so a `:missing_ad_account_id` failure would render as the bare atom string. Unlike story 40's criterion 1001, none of story 37's criteria explicitly require site/date-range detail in the message (972 only requires "not silently skipped", which a visible Failed entry with any error text satisfies), so this isn't filed as a separate issue here.

## Results

- **971** pass (code review): `facebook_ads.ex` uses `integration.access_token` against `graph.facebook.com`, entirely separate from Google's token storage. Live: the integration is listed as "Connected as John Davenport via Facebook" on `/app/integrations`, distinct from the Google-connected cards.
- **972** pass (code review): `resolve_ad_account_id/2` returns `{:error, :missing_ad_account_id}` when no `ad_account_id`/`property_id` is configured, following the exact same "failed, visible in Sync History" pattern already confirmed live for Search Console's analogous case in story 40. Could not reproduce this specific path live: this account's real Facebook integration's token is already permanently expired, and `fetch_metrics/2` checks token expiry *before* resolving the ad account, so clearing `property_id` and triggering the daily sync (confirmed via `trigger-daily-sync`) still produced "Token expired and could not be refreshed" rather than the missing-account error. Restored `property_id` afterward.
- **973** pass (live + code review): the real `facebook-adset-breakdown-toggle` checkbox exists on `/app/integrations/sync-history` with label "Sync Facebook Ads with ad-set-level breakdown (default: campaign-level)"; `phx-click="toggle_facebook_adset_breakdown"` flips `facebook_adset_breakdown`, which the sync trigger passes as `breakdown: :adset` to `DataSync.sync_integration/3` — matching `build_fields/1`'s `:adset` → `adset_name` + `level=adset` behavior in the provider.
- **974** pass (live): DB query confirms all 8 required metric names (`impressions`, `clicks`, `spend`, `cpm`, `cpc`, `ctr`, `conversions`, `conversion_rate`) exist for `provider = 'facebook_ads'`.
- **975/976** pass (code review): same `nil` date-range → provider-default pattern already verified for GA4 (story 35) and Search Console (story 40); `default_date_range/0` computes `{today - 548, today - 1}`.
- **977** pass (code review): `fetch_next_page/7` recursively follows `paging.cursors.after` until exhausted.
- **978** pass (code review): `parse_integer/1` and `parse_float/1` both default to `0`/`0.0` for any non-numeric/unparseable value, so a malformed API field can never crash `transform_row/2`.
- **979** pass (live): the real, already-expired Facebook Ads integration produced a clear "Token expired and could not be refreshed. Please reconnect." entry on every daily-sync trigger. Code review confirms the provider itself separately maps 401/403/429/error-code-190 to distinct, specific error atoms.
- **980** pass (code review + live): `sync_worker.ex` uses `max_attempts: 3` via `Oban.Worker` (Oban's exponential backoff applies between attempts), matching the sync-history page's own copy. The token-expiry failure above is clearly visible in Sync History with a readable message.

No issues filed — all criteria pass.
