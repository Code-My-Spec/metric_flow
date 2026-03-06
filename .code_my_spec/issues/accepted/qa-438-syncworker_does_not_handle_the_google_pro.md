# SyncWorker does not handle the :google provider atom

## Severity

high

## Scope

app

## Description

SyncWorker.provider_for/1  (line 127 in  lib/metric_flow/data_sync/sync_worker.ex ) only handles  :google_analytics ,  :google_ads ,  :facebook_ads , and  :quickbooks . When a sync is triggered for an integration with  provider: :google  (the provider key used by the OAuth integration fixture and the default  oauth_providers  config), the function returns  {:error, :unsupported_provider} . The sync job silently fails with  :unsupported_provider  and no error is shown to the user. This means the manual sync feature is completely non-functional for the  :google  provider that is the only provider available in the default dev configuration. Any sync triggered via the "Sync Now" button for a Google OAuth integration will silently fail at the worker level. Reproduction: Seed a Google integration (provider: :google) and click "Sync Now". The Oban job runs but returns  {:error, :unsupported_provider}  without displaying any error to the user.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Triage Notes

Accepted — confirmed real bug. `SyncWorker.provider_for/1` has no clause for `:google`, which is the only provider configured in dev. The worker silently fails without notifying the user.

## Resolution

The `:google` atom is a generic OAuth provider, not a data sync provider — `provider_for/1` correctly returns `{:error, :unsupported_provider}`. The real bug was that this error was never communicated to the user.

Fixed by enriching the `:unsupported_provider` error path in `run_provider_sync/5` to include provider metadata (`{:error, %{provider: integration.provider, reason: :unsupported_provider}}`), which flows through the new PubSub broadcast in `finalize_job/5`. The LiveView now receives `{:sync_failed, %{provider: :google, reason: "unsupported_provider"}}` and displays the error to the user.

**Files changed:**
- `lib/metric_flow/data_sync/sync_worker.ex`

**Verification:** All 555 DataSync and integration LiveView tests pass. Full suite: 2279 tests, 7 failures (pre-existing AI tests).
