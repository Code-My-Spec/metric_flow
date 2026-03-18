# Connect button initiates OAuth redirect instead of showing informational flash

## Status

resolved

## Severity

low

## Scope

app

## Description

In the Available Platforms section, clicking "Connect" ( [data-role='reconnect-integration'] ) immediately redirects the browser to the OAuth provider's authorization page. The brief expected a flash message "Reconnect {Platform}: authorize your account on the Connect page." to keep the user on the integrations page first. The  handle_event("initiate_connect", ...)  handler calls  redirect(socket, to: ~p"/integrations/oauth/#{provider_str}")  which triggers immediate OAuth without any intermediate feedback to the user. Source:  lib/metric_flow_web/live/integration_live/index.ex ,  handle_event("initiate_connect", ...) . Reproduced at:  http://localhost:4070/integrations , click "Connect" on any available platform.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Changed connect button to redirect to /integrations/connect/:provider with informational flash instead of directly to OAuth
