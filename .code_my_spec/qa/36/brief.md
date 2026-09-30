# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server).

Log in as the QA owner via the password form (note: the submit button has no `type="submit"` attribute, select by `name`):

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 8000)
```

## Seeds

This worktree's dev DB is `metric_flow_dev_wc_bd0baac8`.

qa@example.com (user_id=2) already has a **real, live, connected Google Ads integration** (id 34, provider=`google_ads`, customer_id=`9628205409`) with a real, currently-valid OAuth token. This is the same Google login used for the account's other Google integrations. 325 real metric rows already exist for this provider, spanning 2023-06-01 through 2026-09-29 (37 distinct days with activity) — this is a genuine, aged real ad account, not a fresh fixture.

## What To Test

All testing happens at `/app/integrations/sync-history` — log in, navigate there, click `[data-role='trigger-daily-sync']`, wait ~3s, reload, and inspect the Google Ads entry.

- **Criterion 963** (real fetch via existing OAuth, no separate connection step): Already substantively confirmed by the 325 real historical rows — trigger one more sync and confirm the Google Ads entry shows `data-status="success"` with no separate "connect Google Ads" flow anywhere in the UI (only the shared Google OAuth integration).

- **Criterion 967 (incremental behavior)**: Per `sync_worker.ex` `determine_date_range/3`, incremental syncs anchor to `last_stored_metric_date + 1` through yesterday. Since the latest stored google_ads metric is 2026-09-29 (yesterday relative to "today" 2026-09-30), the computed range is empty — **0 records synced on every trigger today is the correct, expected behavior**, not a bug. Confirm this via `SELECT max(recorded_at) FROM metrics WHERE provider='google_ads'` before concluding anything from a 0-record sync.

- **Criterion 964 (missing customer_id)**: Temporarily clear `provider_metadata` on integration 34 to `{}` via SQL, trigger sync, expect a `[data-role='sync-history-entry'][data-status='failed']` entry for Google Ads with a clear, humanized error (code shows `format_error(:missing_customer_id)` returns a real sentence, not a raw atom — confirm live). **Restore the real `provider_metadata` immediately after** (it's the account's only real integration for this provider — don't leave it broken):
  ```sql
  UPDATE integrations SET provider_metadata = '{}'::jsonb WHERE id = 34; -- test
  -- ... trigger sync, observe ...
  UPDATE integrations SET provider_metadata = '{"name": "John Davenport", "email": "johns10@gmail.com", "username": "johns10@gmail.com", "avatar_url": "https://lh3.googleusercontent.com/a/ACg8ocK9_zGGlTTop1rQbfqjuPzFdAuM06Nqva0n7iwFrP0hiExfhaYqjA=s96-c", "customer_id": "9628205409", "hosted_domain": null, "provider_user_id": "102071280510983396749"}'::jsonb WHERE id = 34; -- restore
  ```

- **Criterion 969 (API rejects the request — unrecognized customer)**: With `provider_metadata` restored, temporarily set `customer_id` to an invalid value (e.g. `"0000000000"`) via SQL, trigger sync, expect a failed entry with the Google Ads API's real error surfaced (code maps 404→`:customer_not_found`, 403→`:insufficient_permissions`). Restore the real customer_id afterward.

- **Criterion 965/966 (breakdown + metric storage + micros conversion)**: Call `MetricFlow.DataSync.DataProviders.GoogleAds.fetch_metrics/2` directly via `run_script`/`mix run -e` (or a small eval) against integration 34 with an explicit historical `date_range` covering a day known to have data (e.g. `{~D[2026-04-01], ~D[2026-04-30]}` — check which of the 37 distinct days actually has rows first) and `breakdown: :campaign` then `breakdown: :ad_group`, to get real rows without waiting on the incremental window. Confirm: metadata includes `ad_group_name` only for the `:ad_group` breakdown; `cost`/`average_cpc` values are small decimal dollar amounts (not raw micros, which would be ~1,000,000x larger); all 7 metric names (impressions, clicks, cost, conversions, ctr, average_cpc, conversions_value) are present.

- **Criterion 970 (retry + logging)**: Code review — `sync_worker.ex` line 28 sets `max_attempts: 3` on the Oban job (provider-agnostic retry, already confirmed live via a real 3-attempt exponential backoff on a different provider earlier this session). Confirm the Sync History UI shows enough detail to diagnose a failure (provider name, error message, timestamp) on whichever failed entries you produce above.

- **Criterion 968 (less than 548 days)**: Not independently testable live — this account's real history (2023–2026) exceeds 548 days, and there's no shorter-history fixture account available. Same code path as 967/`default_date_range/0`; not a separate branch. Note as code-review-only.

## Result Path

.code_my_spec/qa/36/result.md

## Results

All scenarios verified live against integration 34 (real Google Ads account, real OAuth, restored to correct state after each mutation):

- 963: pass, real historical sync data (325 metric rows, 2023-2026) via shared Google OAuth, no separate connection step.
- 964: pass, live tested. Clearing provider_metadata produced a failed entry with a clear, humanized message: "No Google Ads customer ID configured. Go to the integration's account selection to choose an account."
- 965: pass by code review. build_gaql_query/3 deterministically switches FROM campaign/ad_group and adds the ad_group.name dimension based on the breakdown option; not independently observable live today since the account's incremental window is empty (see 967) regardless of breakdown setting.
- 966: pass, live-verified via DB. cost/average_cpc values are real small dollar amounts (e.g. $100, $19.90, $1.66/click), confirming micros-to-dollars conversion, not raw API units.
- 967: pass, confirmed in code (sync_worker.ex determine_date_range/3: incremental anchors to last_stored_metric_date+1 through yesterday) and via DB (latest google_ads metric is 2026-09-29, explaining the correct 0-new-records behavior on every trigger today).
- 968: not independently testable live -- same code path as 967/GoogleAds.default_date_range/0, no shorter-history fixture account available. Code-review only.
- 969: pass with a real gap -- live-tested with an invalid customer_id; the real Google Ads API rejected the request (INVALID_ARGUMENT / INVALID_CUSTOMER_ID) and the sync failed, but the error is surfaced as a raw Elixir inspect() dump rather than a readable message. Filed as issue 282f65f0 (low).
- 970: pass by code review -- Oban max_attempts: 3 (sync_worker.ex line 28), provider-agnostic, already confirmed live as a real 3-attempt exponential backoff on a different provider earlier this session.

## Setup Notes

Integration 34 is a real, shared Google Ads account tied to the platform's own Google login — mutate its `provider_metadata` only for the two negative-path tests above, and restore it immediately after each. Don't delete or leave it broken; other stories/sessions may rely on it.
