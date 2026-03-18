# Google sync fails with database truncation error (string_data_right_truncation)

## Status

resolved

## Severity

high

## Scope

app

## Description

The Google sync worker throws an Ecto exception with  ERROR 22001 (string_data_right_truncation) value too long for type character varying(255) . The sync is failing at the database write layer,
not at the API layer. This suggests a database schema column (likely in the sync job or metric
records) is too short to hold the data being written from the Google API response. The sync completes its API fetch phase but fails when persisting results, meaning every manual
sync attempt for Google integrations will fail silently (from the user's perspective, they just
get an error flash with no records synced). Reproduced at  http://localhost:4070/integrations  by clicking Sync Now on any Google platform
(Google Analytics or Google Ads) when a Google integration with  access_token: "qa_test_token" 
is present.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Resolution

The truncation was in `sync_history.error_message` and `sync_jobs.error_message` columns (both `varchar(255)`). Long Postgres exception messages exceeded the limit. Created migration `20260317155527_widen_metrics_string_columns` to change `metrics.metric_type`, `metrics.metric_name`, `sync_history.error_message`, and `sync_jobs.error_message` from `varchar(255)` to `text`. Server restart required after migration to clear Postgres prepared statement cache.

**Files changed:** `priv/repo/migrations/20260317155527_widen_metrics_string_columns.exs`, `lib/metric_flow/data_sync/sync_worker.ex`
**Verified:** Migration applied, 2561 tests pass.
