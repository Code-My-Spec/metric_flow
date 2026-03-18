# SyncJob schema rejects :google provider — create_sync_job fails silently as "Integration not found"

## Status

resolved

## Severity

high

## Scope

app

## Description

MetricFlow.DataSync.SyncJob  defines its provider enum as  @providers [:google_analytics, :google_ads, :facebook_ads, :quickbooks]  (line 39 of  lib/metric_flow/data_sync/sync_job.ex ). The  :google  atom is absent. When a user clicks "Sync Now" for their Google integration: DataSync.sync_integration(scope, :google)  calls  SyncJobRepository.create_sync_job(scope, integration.id, %{provider: :google}) SyncJob.changeset/2  casts  provider: :google  against the Ecto.Enum —  :google  is not a valid value so the cast is rejected (field becomes invalid) create_sync_job  returns  {:error, %Ecto.Changeset{}}  instead of  {:ok, sync_job} The  with  chain in  sync_integration/2  propagates  {:error, changeset} handle_event("sync", ...)  catches  {:error, _reason}  and shows "Integration not found." — incorrect error message No Oban job is enqueued, no sync is performed, no loading state is shown Confirmed by: empty  sync_jobs  table after clicking Sync Now, and the error flash appears immediately (not after a server-side delay). Reproduction: Log in as  qa@example.com , navigate to  http://localhost:4070/integrations , click "Sync Now" on the Google card. Expected: "Sync started for Google" flash and loading state. Actual: "Integration not found." flash, button stays enabled. Fix: Add  :google  to  @providers  in  lib/metric_flow/data_sync/sync_job.ex , and generate a migration to update the column constraint if necessary. Also update  SyncWorker.providers_for/1  to ensure  :google  is handled (it already has a clause:  def providers_for(:google), do: {:ok, [GoogleAnalytics, GoogleAds]} ). Also consider improving the error message in  handle_event("sync", ...)  to distinguish between "integration not found in DB" vs "sync job creation failed" vs "unsupported provider" for better user feedback.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Resolution

Added `:google` to the `@providers` list in `SyncJob` schema. The migration uses `:string` type (not a DB-level enum), so no migration was needed — the fix is application-level only. `SyncWorker.providers_for(:google)` already handles the `:google` provider correctly.

**Files changed:**
- `lib/metric_flow/data_sync/sync_job.ex` — added `:google` to `@providers`

**Verification:** All 2561 tests pass.
