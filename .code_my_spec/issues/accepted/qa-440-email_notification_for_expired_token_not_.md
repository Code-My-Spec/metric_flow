# Email notification for expired token not implemented

## Status

resolved

## Severity

medium

## Scope

app

## Description

The acceptance criterion "user receives email notification when credentials expire" is not implemented. No code in  DataSync.SyncWorker ,  DataSync.sync_integration/2 , or  IntegrationLive.Index  sends an email notification on token expiry. The dev mailbox at  /dev/mailbox  would show no expiry-related emails. This was noted as a known gap in the brief (item 5) but is recorded here for completeness as it represents an unmet acceptance criterion.

## Source

QA Story 440 — `.code_my_spec/qa/440/result.md`

## Resolution

Implemented email notification for expired integration tokens. Added deliver_token_expired_notification/2 to MetricFlow.Users.UserNotifier, added notify_token_expired/2 public function to MetricFlow.Users context, and wired the call into MetricFlow.DataSync.SyncWorker.execute_sync/5 when ensure_fresh_tokens returns {:error, :token_expired}. The notification is sent after recording the failure history, with a logged warning if delivery fails (non-blocking). Files changed: lib/metric_flow/users/user_notifier.ex, lib/metric_flow/users.ex, lib/metric_flow/data_sync/sync_worker.ex. Verified with MIX_ENV=test mix agent_test — all relevant tests pass.
