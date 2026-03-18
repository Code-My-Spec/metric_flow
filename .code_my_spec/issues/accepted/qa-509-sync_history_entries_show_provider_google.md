# Sync history entries show provider "Google" instead of "Google Analytics"

## Status

resolved

## Severity

high

## Scope

app

## Description

The  sync_history  table contains 36 records. All "Google" provider entries use  provider: :google  rather than  provider: :google_analytics  or  provider: :google_ads . In the  SyncHistory  LiveView,  @provider_names  maps  :google  to  "Google"  and  :google_analytics  to  "Google Analytics" . Because the provider is stored as  :google , all these entries display as "Google" in the sync history list rather than the expected "Google Analytics" or "Google Ads". This makes it impossible for users to distinguish which Google platform synced (Google Analytics vs Google Ads). The SyncWorker appears to be using the integration's OAuth provider name ( :google ) rather than the data provider name ( :google_analytics / :google_ads ) when creating sync history records. Reproduced at  http://localhost:4070/integrations/sync-history . All non-Facebook entries show "Google" as the provider name.

## Source

QA Story 509 — `.code_my_spec/qa/509/result.md`

## Resolution

SyncWorker now records per-provider sync history using each data provider module's provider/0 function (:google_analytics, :google_ads) instead of the OAuth integration's provider (:google). Added record_history_with_provider/8 and updated run_all_providers and persist_and_record_success to record separate entries per provider module. Files changed: lib/metric_flow/data_sync/sync_worker.ex. Verified: 2561 tests pass.
