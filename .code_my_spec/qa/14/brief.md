# Story 14 QA Brief: Automated Daily Data Sync

## Tool

web (SyncHistory LiveView) + direct DB/mix inspection for backend verification

## Auth

Login at `http://127.0.0.1:59302/users/log-in` with password form:
- email: `qa@example.com`
- password: `hello world!`
- Submit via the password login form (`#login_form_password`).

## Seeds

- Base seeds already loaded (qa@example.com owns QA Test Account with connected integrations from prior stories this session).
- Environment note: this checkout's dev server requires `DATABASE_NAME=metric_flow_dev_wc_bd0baac8` for any `mix`/SQL shell command to hit the same DB the running app serves (port 59302). Confirmed and fixed a PendingMigrationError at session start (issue 686cd7aa) caused by this story's own migration never having run against the correct per-worktree DB.
- Use `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 MIX_ENV=dev mix run -e '...'` or direct `psql metric_flow_dev_wc_bd0baac8` for any backend verification/manipulation (forcing token expiry, checking sync_history rows, checking metrics rows).

## What To Test

- **609 (cron scheduled)**: confirm `config/runtime.exs` registers `{"0 2 * * *", MetricFlow.DataSync.Scheduler, ...}` under `Oban.Plugins.Cron` (code review — not practically waitable live). Cross-check `DataSync.Scheduler` actually enqueues `SyncWorker` jobs by reading its source.
- **610 (pulls from every active integration)**: navigate to `/app/integrations/sync-history`, click "Trigger Sync Now (Dev)", confirm a `sync-history-entry` appears for every one of the account's connected integrations, not just one.
- **611/612 (first sync backfills, limited to API allows)**: find or create an integration with zero prior `sync_history` rows, trigger sync, confirm the resulting entry carries `data-sync-type="initial"` and the "Backfilled the maximum history available..." notice. Cross-check the provider's `@default_date_range_days` (548 days) is what's actually used as the fetch window.
- **613 (debits/credits as metrics)**: trigger a QuickBooks sync (if connected) or directly invoke the QuickBooks provider via a script, then query the `metrics` table for rows with `normalized_metric_name in ("revenue","expenses")` and `metric_type = "financial"` tied to today's sync.
- **614 (metrics + review + financial together in one cycle)**: trigger the full "Sync Now (Dev)" across all integrations and confirm sync_history entries exist for marketing (metrics), review (if a reviews-capable integration is connected), and financial (QuickBooks) providers from the same trigger.
- **615/616 (token refresh / refresh failure)**: via SQL, set an integration's `token_expires_at` to the past. Case A: leave a plausible `refresh_token` in place and trigger sync — confirm `Integrations.refresh_token/2` is invoked (check `Integration.expired?`/`ensure_fresh_tokens` logic in `sync_worker.ex:376-390`) and the integration's token is refreshed (or the call fails against the real OAuth endpoint in a controlled, identifiable way). Case B: clear the refresh token entirely, trigger sync, confirm the sync fails with `error_message = "Token expired and could not be refreshed"` and a `sync-history-entry[data-status=failed]` with that message appears.
- **617/618 (retry up to 3x exponential backoff, marked failed after exhaustion)**: confirmed by code review — `SyncWorker` is `use Oban.Worker, max_attempts: 3` (Oban's own default exponential backoff applies uniquely per attempt). Not practically live-testable within a QA session due to backoff delay; rely on the passing BDD spex plus this code confirmation. Note in result if spex don't actually exercise 3 real attempts.
- **619 (errors logged with debugging detail)**: force a sync failure (e.g. Case B above, or an integration with a provider the fetch will reject) and confirm `Logger.error` output includes `integration_id`, `user_id`, and `reason` (see `sync_worker.ex:88-91`, `:171-173`).
- **620 (default date range excludes today)**: navigate to `/app/integrations/sync-history`, confirm the `[data-role='date-range']` text shows yesterday's date and not today's (this is what the existing spex checks). **Also** verify the *actual* fetch window used by a live-triggered sync: read `lib/metric_flow/data_sync/data_providers/google_ads.ex:77-81` (and facebook_ads.ex, quick_books.ex) — `default_date_range/0` returns `{start_date, today}`, i.e. the real fetch end date is `Date.utc_today()`, not yesterday. This looks like a real gap between the UI's claim ("today excluded, incomplete day") and the actual query window used during a real sync — confirm by checking whether a freshly-triggered sync run creates/could create a metric row dated today, or whether the provider APIs themselves naturally never return partial current-day data (check test fixtures/mocks for clues) before filing.

## Result Path

`.code_my_spec/qa/14/result.md` (not read by the harness — findings live in filed issues + submit_qa_result only, per the task prompt).

## Setup Notes

Spex tally at session start showed 24 failing project-wide (unrelated pre-existing state, not this story) — noted for awareness, not investigated as part of this QA pass unless directly relevant to story 14's own criteria.

## Results

Executed live against qa@example.com's 7 real seeded integrations (6 of which had `expires_at` already in the past relative to today, one — facebook_ads — with no refresh token at all, a naturally-occurring live test of 615/616).

- **609** pass — `Oban.Plugins.Cron` registers `{"0 2 * * *", MetricFlow.DataSync.Scheduler, ...}` (config/runtime.exs:213).
- **610** **FAIL** — facebook_ads (connected, expired, no refresh token) got zero Oban job, zero SyncJob, zero sync_history row from a full "Trigger Sync Now" — silently excluded rather than synced or failed. Issue 4a3d10af (critical).
- **611/612** pass — `determine_sync_type/1` correctly detects no-prior-history as `:initial`; providers' 548-day default backfill window confirmed in code; "Initial Sync"/backfill-limit-notice badges confirmed present in `sync_history.ex`.
- **613** pass — live: QuickBooks sync created 1098 `revenue` + 1098 `expenses` financial metrics, confirmed via DB query.
- **614** **FAIL** — review-data sync (`google_business_reviews`) has zero implementation anywhere (no data provider module, `providers_for/1` has no clause, nothing ever writes to the `reviews` table). Its own spex only passes because a *failed* sync entry's provider name happens to render in the HTML. Issue f736bee3 (high).
- **615** pass — live: 4 expired-with-refresh-token integrations (google_ads, google_search_console, google_analytics, google_business) all refreshed and synced successfully in one trigger.
- **616** pass — live: quickbooks (expired, has refresh_token, but the real refresh call fails) correctly recorded `sync_history.status=failed`, `error_message='Token expired and could not be refreshed'`.
- **617/618** pass — live: quickbooks' Oban job made 3 real attempts with backoff delay (~18s between attempts 1 and 2), ended `state=discarded, attempt=3/3`; `sync_jobs.status` reached its terminal `failed` value only after that exhaustion.
- **619** pass — confirmed via `mix test` output: `Logger.error` lines include `integration_id`, `user_id`/`provider_mod`, and `reason` for every failure path.
- **620** **FAIL** — the SyncHistory page's displayed text ("yesterday — today excluded") is correct and its own spex passes, but the *real* fetch window used by an actual sync (`determine_date_range/3` for every incremental/daily sync, and every provider's `default_date_range/0` for initial syncs) ends at `Date.utc_today()`, not yesterday — the display is decorative, not what's actually queried. Issue 3ad77a15 (medium).

Also filed and self-resolved a qa-scope blocker: this worktree's dev DB had a pending migration (this story's own `add_sync_type_to_sync_history`) causing a total PendingMigrationError outage at session start — issue 686cd7aa.

## Retest (commit 428e70d)

- **4a3d10af (critical, 610/616)**: FIXED, confirmed live. facebook_ads (expired, no refresh token) now gets a real Oban job, SyncJob, and a persisted sync_history row (status=failed, 'Token expired and could not be refreshed').
- **3ad77a15 (medium, 620)**: FIXED, confirmed live and in code. determine_date_range/3's incremental branch and all provider default ranges now end at yesterday. A transient 'bad_request' on google_analytics during retest traced to a stray metric dated today created by my own earlier pre-fix trigger (repro-consumed-itself) -- cleaned up, not a product bug.
- **f736bee3 (high, 614)**: PARTIALLY FIXED -- works correctly for providers recognized by SyncJob's own Ecto.Enum but unimplemented in SyncWorker (e.g. google_business_reviews, per the coder's own verification). But found a new regression: providers outside that enum entirely (e.g. codemyspec, a real integration on this account unrelated to data-sync) still silently vanish -- create_sync_job fails changeset validation before any SyncJob/Oban job exists, and both the LiveView trigger and the real Scheduler discard that error silently. Filed as issue 8c617ca8 (high).
