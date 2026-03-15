# Disconnect confirmation uses inline panel, not modal overlay

## Status

accepted

## Severity

low

## Scope

app

## Description

The disconnect confirmation UI is rendered as an inline panel that expands within the integration card ( [data-role='disconnect-warning'] ), not as a modal dialog. The brief and UI spec both describe a  .modal  overlay with  class*='modal-open' . The inline panel is functional and provides the warning message and confirm/cancel buttons, but it does not match the spec's "Disconnect confirmation modal" description. The spec's Design section says: "Disconnect confirmation modal (shown when  disconnecting_provider  is set):  .modal  overlay containing...". Reproduction: Navigate to  /integrations , click "Disconnect" on any connected card — a panel expands within the card rather than a full-page modal overlay appearing.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
