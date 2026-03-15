# Disconnect flash message missing "no new data will sync" clause

## Status

accepted

## Severity

low

## Scope

app

## Description

After confirming disconnect, the flash message reads: "Disconnected from {Platform}. Historical data is retained." The spec and brief both indicate the message should include the additional clause: "no new data will sync after disconnecting." or equivalent. The current message omits this information. Source location:  lib/metric_flow_web/live/integration_live/index.ex  in the  handle_event("disconnect", ...)  handler,  put_flash(:info, "Disconnected from #{name}. Historical data is retained.") .

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
