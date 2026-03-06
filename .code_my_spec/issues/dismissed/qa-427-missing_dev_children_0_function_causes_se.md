# Missing dev_children/0 function causes server crash on restart

## Severity

high

## Scope

qa

## Description

lib/metric_flow_web/application.ex  calls  dev_children()  at line 22 but the function was not defined anywhere in the codebase. This caused  mix compile  to fail with: error: undefined function dev_children/0 (expected MetricFlowWeb.Application to define such a function) The server was running before this QA session started (presumably started by the developer before this function went missing), but once stopped it could not be restarted. This blocked QA testing mid-session when the server crashed due to a LiveView WebSocket reconnect issue. A fix was applied during this session (adding a no-op  dev_children/0 ). The user has since updated this to the correct implementation using  ClientUtils.CloudflareTunnel . The app now compiles and starts. Reproduction: Stop the Phoenix server and run  mix phx.server  without the fix applied.

## Source

QA Story 427 — `.code_my_spec/qa/427/result.md`

## Triage Notes

Dismissed — already fixed during the QA session. The correct `dev_children/0` implementation using `ClientUtils.CloudflareTunnel` is in place.
