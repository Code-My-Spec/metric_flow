# Connect button initiates OAuth instead of showing informational flash

## Status

incoming

## Severity

info

## Scope

app

## Description

In the Available Platforms section, clicking the "Connect" button ( [data-role='reconnect-integration'] ) immediately redirects the user to the OAuth provider (e.g. Facebook's login page). The brief expected a flash message like "Reconnect {Platform}: authorize your account on the Connect page." but no flash is shown. The behavior (direct OAuth redirect) is not necessarily wrong from a UX standpoint — it gets the user to auth faster — but it differs from the brief's expected behavior. If the intent is to show a flash and keep the user on the integrations page first, the  handle_event("initiate_connect", ...)  handler needs to be changed.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
