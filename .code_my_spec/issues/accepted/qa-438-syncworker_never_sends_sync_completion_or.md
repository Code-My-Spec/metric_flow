# SyncWorker never sends sync completion or failure messages to the LiveView

## Severity

high

## Scope

app

## Description

MetricFlow.DataSync.SyncWorker.perform/1  completes its work (updating the  SyncJob  database record to  :completed  or  :failed ) but never sends a  {:sync_completed, ...}  or  {:sync_failed, ...}  message to the LiveView process. The  IntegrationLive.Index  LiveView has correct  handle_info  callbacks for both messages (lines 317–343 in  lib/metric_flow_web/live/integration_live/index.ex ), but they are never invoked during a real sync because the worker does not send them. As a result, clicking "Sync Now" permanently disables the button and shows the "Syncing" spinner until the user manually refreshes the page. Acceptance criteria 4053 (success message with timestamp and records synced) and 4054 (error details if sync fails) are completely unmet in the running application. Reproduction: Log in as  qa@example.com , navigate to  /integrations , click "Sync Now" on the Google card. The page never transitions out of the "Syncing" state.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Triage Notes

Accepted — confirmed real bug. The SyncWorker updates the database but never sends PubSub/process messages to the LiveView, leaving the UI permanently stuck in "Syncing" state.

## Resolution

Added PubSub broadcasting to SyncWorker and PubSub subscription to the LiveView:

1. `SyncWorker.finalize_job/5` now broadcasts `{:sync_completed, meta}` on success and `{:sync_failed, meta}` on failure via `Phoenix.PubSub` on a user-scoped topic (`"user_sync:#{user_id}"`).
2. `persist_and_record_success/5` returns enriched `{:ok, %{provider: ..., records_synced: ..., completed_at: ...}}` instead of bare `:ok`.
3. `run_provider_sync/5` wraps error returns with provider info for the enriched `finalize_job` clause.
4. `IntegrationLive.Index.mount/3` subscribes to `"user_sync:#{scope.user.id}"` when connected, pairing with the existing `handle_info` callbacks.

**Files changed:**
- `lib/metric_flow/data_sync/sync_worker.ex`
- `lib/metric_flow_web/live/integration_live/index.ex`

**Verification:** All 555 DataSync and integration LiveView tests pass. Full suite: 2279 tests, 7 failures (pre-existing AI tests).
