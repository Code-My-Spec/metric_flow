# Sync Now on expired integration shows wrong flash message

## Status

resolved

## Severity

high

## Scope

app

## Description

When a user clicks "Sync Now" on a Google Analytics integration with an expired token (no refresh token), the LiveView shows the flash error  "Integration not found."  instead of the expected  "token has expired. Please reconnect."  message. Root cause:  IntegrationLive.Index.handle_event("sync", ...)  in  lib/metric_flow_web/live/integration_live/index.ex  (lines 300–302) handles both  :not_found  and  :not_connected  with the same flash message: {:error, reason} when reason in [:not_found, :not_connected] ->
  {:noreply, put_flash(socket, :error, "Integration not found.")} The fix is to handle  :not_connected  separately with a message directing the user to reconnect, such as:  "Your Google Analytics token has expired. Please reconnect."  The  DataSync.SyncWorker.format_error(:token_expired)  function already has the right message template — it just needs to be wired into the LiveView handler for the pre-dispatch  :not_connected  case. Reproduction steps: Seed an expired  google_analytics  integration:  mix run priv/repo/qa_seeds_440.exs Log in as  qa@example.com  and navigate to  /integrations Click "Sync Now" on the Google Analytics card Observe flash message — shows "Integration not found." instead of reconnection prompt

## Source

QA Story 440 — `.code_my_spec/qa/440/result.md`

## Resolution

Fixed by splitting the :not_connected and :not_found error handling in IntegrationLive.Index handle_event("sync"). The :not_connected case now shows 'Your [platform] token has expired. Please reconnect.' instead of the generic 'Integration not found.' message. Updated both the platform+provider and provider-only sync event handlers. Updated the existing :not_connected test to properly seed an expired integration without a refresh token (using past expires_at and nil refresh_token overrides) so it actually triggers :not_connected rather than :not_found. Files changed: lib/metric_flow_web/live/integration_live/index.ex, test/metric_flow_web/live/integration_live/index_test.exs. Verified with MIX_ENV=test mix agent_test — 29 tests pass.
