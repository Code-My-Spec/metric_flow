# Confirm disconnect button labeled "Confirm" instead of "Disconnect"

## Status

accepted

## Severity

low

## Scope

app

## Description

The  [data-role='confirm-disconnect']  button inside the disconnect warning panel displays "Confirm" rather than "Disconnect". The spec's Design section says the confirm button should be labeled "Disconnect". Users may expect explicit "Disconnect" text on the final confirmation action. Reproduction: Click "Disconnect" on a connected card → the warning panel shows a button labeled "Confirm" (not "Disconnect").

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
