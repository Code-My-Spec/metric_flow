# Spex files in story 518 use direct send() instead of UI-driven sync

## Status

incoming

## Severity

medium

## Scope

test

## Description

All 11 spex files in `test/spex/518_sync_quickbooks_account_transaction_data/` use `send(context.view.pid, {:sync_completed, ...})` or `send(context.view.pid, {:sync_failed, ...})` to simulate sync behavior. This violates the `NoDirectSendInSpex` credo rule (CMS0001) which requires driving behavior through the UI or public API.

The credo check produces 275+ warnings across these files.

## Root Cause

The spex files were generated to test sync history display by injecting messages directly into the LiveView process, bypassing the actual sync flow entirely. This means the tests don't verify that:
- Clicking "Sync Now" actually enqueues and executes a sync job
- The SyncWorker correctly fetches data via the QuickBooks API
- Sync results are correctly persisted to SyncHistory
- The sync history page correctly loads persisted results from the database

## Attempted Fix

Rewrote all 11 files to drive sync through the UI:
1. Create a QuickBooks integration fixture
2. Navigate to `/integrations`
3. Click "Sync Now" button (`[data-platform='quickbooks'] button`)
4. Use ReqCassette with `quickbooks_fetch_metrics` cassette (mode: :replay, match_requests_on: [:method]) to replay API responses
5. Navigate to `/integrations/sync-history` to verify results

### Blockers Encountered

**Oban manual mode + LiveView process boundary**: Oban is configured with `testing: :manual` in test.exs, which captures jobs without executing them. When the user clicks "Sync Now", the LiveView's `handle_event` calls `DataSync.sync_integration` which inserts an Oban job — but it never runs.

- `Oban.Testing.with_testing_mode(:inline, fn -> ... end)` does NOT work because it uses `Process.put(:oban_testing, mode)` which only affects the test process. The LiveView runs in a separate process and doesn't see the process dictionary override.
- `Oban.drain_queue(queue: :sync)` does nothing in manual mode — jobs are captured, not inserted to the DB.
- `Oban.Testing.perform_job/3` works but requires extracting enqueued jobs and calling them manually, which defeats the purpose of UI-driven testing.
- Switching `config/test.exs` to `testing: :inline` globally makes the job execute during `render_click()`, but then `finalize_job` returns `{:error, ...}` for failure scenarios which causes the inline engine to mark the job as retryable/failed and this propagates as an exception through the LiveView.

**SyncWorker http_plug injection**: The SyncWorker supports `http_plug` in job args for test HTTP interception, but `DataSync.sync_integration` (the UI path) doesn't pass it through. Added `Application.get_env(:metric_flow, :sync_http_plug)` as a fallback in `resolve_plug/1` — this part works correctly.

**SyncWorker error returns**: `finalize_job` returns `{:error, reason}` for handled failures (already recorded in SyncJob/SyncHistory). In inline mode, this causes Oban to treat the job as failed and raise in the calling process. Fix: return `:ok` from `finalize_job` for handled failures since retrying is not desired.

## Proposed Plan

### Option A: Fix inline mode end-to-end (recommended)

1. **Change `config/test.exs`** to `testing: :inline` (or create a `SpexCase` that switches to inline per-test)
2. **Fix `SyncWorker.finalize_job/5`** to return `:ok` for handled failures (the failure is already persisted)
3. **Add `resolve_plug/1` fallback** to read from `Application.get_env(:metric_flow, :sync_http_plug)` when no plug in job args
4. **Debug cassette replay**: The cassette plug IS set and reaches the SyncWorker, but HTTP requests still hit the real QuickBooks API. Need to verify that `Req.get!` with `:plug` option correctly uses the ReqCassette plug when called from within the Oban inline executor context. This is the remaining unsolved blocker.

### Option B: Use Oban.Testing.perform_job explicitly

1. Keep `testing: :manual`
2. After clicking "Sync Now", extract the enqueued job and call `Oban.Testing.perform_job/3` within the cassette block
3. Less clean (uses Oban internals in spex) but avoids the inline mode complications

### Required Changes (both options)

- `lib/metric_flow/data_sync/sync_worker.ex`: Add Application env fallback in `resolve_plug/1`; return `:ok` from `finalize_job` for handled failures
- `test/support/spex_case.ex`: New test case module for spex files (optional, for option A)
- `config/test.exs`: Switch to `testing: :inline` (option A only)
- All 11 spex files: Rewrite to UI-driven pattern with ReqCassette

## Files Affected

- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4828_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4829_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4830_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4831_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4832_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4833_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4834_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4835_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4836_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4837_*_spex.exs`
- `test/spex/518_sync_quickbooks_account_transaction_data/criterion_4838_*_spex.exs`
- `lib/metric_flow/data_sync/sync_worker.ex`
- `config/test.exs` (option A)
- `test/support/spex_case.ex` (new, option A)
