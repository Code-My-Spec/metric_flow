# Sync failure flash message is generic instead of showing error details

## Status

resolved

## Severity

medium

## Scope

app

## Description

Every manual sync attempt results in an immediate failure. The Oban worker attempts to fetch data from the provider using the seed access token ( qa_test_token ) and fails with an API error. The user sees two consecutive flashes: "Sync started for Facebook Ads" (info) and "Sync failed for Facebook. Please check your connection and try again." (error). The success path — showing the "Synced N records at timestamp" badge — cannot be exercised with the current seed data. The sync failure flash message does not include the specific error reason (it always says "Please check your connection and try again" rather than the actual error detail). The BDD spec for criterion 4054 expects error details to be displayed. The flash message shown is generic rather than diagnostic.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`

## Resolution

Fixed `handle_info({:sync_failed, ...}, socket)` in `MetricFlowWeb.IntegrationLive.Index` to use the `reason` field from the PubSub message instead of discarding it. The `reason` parameter was previously pattern-matched as `_reason` (unused). Now a `build_failure_message/2` private helper formats the flash:

- When `reason` is a non-empty string: `"Sync failed for {Provider}: {reason}"` — shows the specific error detail
- When `reason` is nil, atom, or empty: falls back to `"Sync failed for {Provider}. Please check your connection and try again."`

The `SyncWorker` already formats error reasons into human-readable strings via its `format_error/1` helper (e.g. `"Authorization expired. Please reconnect the integration."`, `"No Google Analytics property configured."`), so those descriptions now flow through to the user-facing flash message.

Files changed:
- `lib/metric_flow_web/live/integration_live/index.ex` — changed `_reason` to `reason` in the `{:sync_failed}` handler, added `build_failure_message/2` private helper

Verified: all 29 unit tests in `integration_live/index_test.exs` pass, and the BDD spex for criterion 4054 passes (the test sends `reason: "API rate limit exceeded"` and asserts the page contains that text).
