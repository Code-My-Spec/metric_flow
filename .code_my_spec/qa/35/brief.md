# Qa Story Brief

## Tool

web

## Auth

App URL for this session: `http://127.0.0.1:59302` (this worktree's own dev server).

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_wait_for_load()
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 8000)
```

## Seeds

Base seeds already in place (qa@example.com / hello world!). This account has a real, connected Google Analytics integration (provider `google_analytics`, property `properties/343881087`, confirmed during story 16's session) with real sync history already present.

## What To Test

- **293/631** (all 11 core GA4 metrics synced: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers): trigger a live sync via `/app/integrations` "Sync Now" on Google Analytics, then query the DB (`metrics` table, `provider = 'google_analytics'`) for the **distinct set of `metric_name` values actually stored**. Compare against the required 11. Code review of `lib/metric_flow/data_sync/data_providers/google_analytics.ex` `@metric_names` already shows a hardcoded list of 6 different metric names (`sessions`, `screenPageViews`, `activeUsers`, `bounceRate`, `averageSessionDuration`, `newUsers`) that overlaps only 4 with the required 11 and includes 2 not required at all — live DB check confirms whether this is really what gets persisted.
- **295/634** (first sync backfills up to 548 days): for a fresh GA4 integration with no prior sync history, confirm `determine_date_range` returns `nil` (full backfill), which the provider's own `resolve_date_range/1` turns into `{today - 548, today - 1}`. Code-review pass (`google_analytics.ex:211-220`, `sync_worker.ex:230`); live value can't be distinguished from a shorter backfill without controlling the property's actual history length.
- **296/636** (subsequent sync fetches from day after last stored date through yesterday, never today): code-review pass — `sync_worker.ex:232-237` computes `{Date.add(last_date, 1), Date.add(Date.utc_today(), -1)}` for `:incremental` syncs. Live-verify by triggering a second sync on the already-synced integration and confirming via DB that no metric row with `recorded_at` = today exists afterward.
- **298/638** (GA4 quota limit triggers backoff/retry): searched `sync_worker.ex` and `sync_job.ex` for retry/backoff config — found none specific to quota handling. Check `test/spex/35_sync_google_analytics_4_data/criterion_298_*.exs` for what's actually asserted; if it only checks a generic Oban retry count rather than quota-specific backoff, note that as a criteria/implementation gap.
- **299/639** (no-traffic day stores a zero-value record instead of a gap): check `criterion_299_*.exs` spex for the exact assertion; grep of `sync_worker.ex` and `metrics/` found no explicit zero-fill logic outside of a `metric_repository.ex` dashboard summary helper — likely relies on the GA4 API itself returning a zero-value row rather than the app synthesizing one. Note as a code-review finding.
- **300/640 & 301/641** (canonical mapping / platform-specific label): read `NormalizedMetric.normalize/2`'s `@google_analytics` map (`lib/metric_flow/metrics/normalized_metric.ex:25`) against the 6 *actually-fetched* metric names — confirm each either maps to a canonical name or falls through to a "Google Analytics: X" platform-specific label. Since this only covers the 6 fetched metrics, the 7 missing required metrics can't be assessed for mapping at all.
- **302/642** (sync failures logged with API error, surfaced in Sync Status/History): force a failure (e.g. temporarily set the integration's `access_token` to an invalid value via SQL, trigger sync, confirm a `failed` sync-history entry with an error message appears on `/app/integrations/sync-history`), then restore the token.
- **303/643** (stored data scoped to date dimension only, no source/medium or page breakdowns): confirm live via DB that `dimensions` column for `google_analytics` metric rows contains only `date`, never `sessionSource`/`sessionMedium`/`pagePath` — the automated sync path never passes a `:breakdown` option (`sync_worker.ex` `build_fetch_opts/2` has no breakdown key), so this should hold structurally.
- **632** (missing core metric for a property doesn't fail the whole sync): review `transform_rows/2` — it zips `@metric_names` against whatever `metricValues` the API returns per row; a short/missing value list would just zip to fewer pairs rather than crash. Code-review pass given the metric list itself is already wrong.

## Result Path

.code_my_spec/qa/35/result.md

## Setup Notes

The core, highest-severity finding for this story is expected to be the metric list mismatch (293/631): the implementation's `@metric_names` in `google_analytics.ex` doesn't match the 11 metrics the story's own acceptance criteria and BDD moduledoc require. Criterion 293's spex (`criterion_293_system_syncs_the_following_ga4_metrics_as_core_daily_values_activeusers_active7dayusers_active28dayusers_newusers_engagedsessions_sessions_userengagementduration_screenpageviews_eventcount_keyevents_scrolledusers_spex.exs`) only asserts that a sync-history entry shows the "Google Analytics" provider name — it never inspects which metrics were actually synced, so it passes regardless of this gap.

## Retest (after fixes for 0837169f, 291cf8b6)

Both fixes confirmed in code:
- `google_analytics.ex`'s `@metric_names` now lists exactly the 11 required metrics (activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers).
- `metric.ex`/`metric_repository.ex` no longer force-downcase `metric_name` on insert (grep for `downcase`/`normalize_metric_name` in both files returns nothing).

Live verification via the browser was attempted (triggered "Sync Now" on the real, connected `properties/343881087` integration three times), but every attempt failed against the real Google Analytics API with `error_message: "bad_request"` — visible directly in `sync_history` on this worktree's own DB (`metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev` a bare `mix run` shell connects to by default). This is a live-API/credential issue on this QA account, not an application bug, and blocks a true end-to-end confirmation of the fix via a real sync. Filed as qa-scope issue.

Corroborated instead via the dedicated unit suite: `mix test test/metric_flow/data_sync/data_providers/google_analytics_test.exs` (35/35 pass, fixtures use the new 11-metric list) and `mix test test/metric_flow/metrics/` (93/93 pass, no casing-related assertions broken).
