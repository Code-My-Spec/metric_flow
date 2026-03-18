# Sync failure flash message exposes raw Elixir tuple for Google sync exceptions

## Status

resolved

## Severity

high

## Scope

app

## Description

When the Google sync worker catches an exception (e.g., a Postgres string_data_right_truncation
error), it returns  {:error, {:exception, "ERROR 22001 ..."}} . The  format_error/1  function
in  SyncWorker  does not handle the  {:exception, reason}  tuple shape, so it falls through to
the catch-all  inspect(reason)  clause, producing the flash message: Sync failed for Google: {:exception, "ERROR 22001 (string_data_right_truncation) value too long for type character varying(255)"} This exposes internal Elixir error structure and a raw Postgres error string to the user. The
 format_error  function should handle the  {:exception, message}  tuple shape and return a
friendly message such as "An unexpected error occurred during sync. Please try again." The underlying cause appears to be the Google sync worker attempting to write data with a field
that exceeds the database column length (255 chars), likely a metadata field or account identifier
that is longer than the schema allows. Reproduced at  http://localhost:4070/integrations  by clicking Sync Now on Google Analytics or
Google Ads when a Google integration is connected.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Resolution

Added `{:exception, _message}` clause to `format_error/1` in `SyncWorker` that returns a user-friendly message instead of exposing the raw Elixir tuple.

**Files changed:** `lib/metric_flow/data_sync/sync_worker.ex`
**Verified:** 2561 tests pass.
