# Sync Now button never triggers actual data sync — UI enters permanent Syncing state

## Status

accepted

## Severity

high

## Scope

app

## Description

The  handle_event("sync", ...)  handler in  MetricFlowWeb.IntegrationLive.Index  (lines 264-278 of  lib/metric_flow_web/live/integration_live/index.ex ) updates the LiveView's  @syncing  MapSet and shows the "Sync started for Google" flash, but it does not call  DataSync.sync_integration/2  or start any Oban worker. As a result: The "Syncing" spinner and disabled button state appear immediately after clicking — this is correct UI behavior. No  {:sync_completed, ...}  or  {:sync_failed, ...}  message is ever sent to the LiveView PID. The "Syncing" spinner and disabled button state are permanent for the duration of the LiveView session. The user cannot click "Sync Now" again without reloading the page. No actual data is synced from any external platform. The fix is to call  DataSync.sync_integration(scope, provider)  inside the  handle_event("sync", ...)  handler. On  {:ok, _sync_job} , the LiveView should add the provider to  @syncing . The  SyncWorker  should then send  {:sync_completed, ...}  or  {:sync_failed, ...}  to the LiveView PID when the Oban job finishes. Reproduced at:  http://localhost:4070/integrations  — click "Sync Now" on any connected integration and observe the spinner never resolves.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`
