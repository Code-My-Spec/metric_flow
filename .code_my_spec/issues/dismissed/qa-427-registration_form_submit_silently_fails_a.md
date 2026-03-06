# Registration form submit silently fails after server restart

## Severity

medium

## Scope

qa

## Description

After the Phoenix server was restarted mid-session (due to the  dev_children/0  compile error), the registration form at  /users/register  began silently failing. Submitting the form with all required fields filled (email, password, account_name) returned no confirmation page and no visible error. The form simply reset to blank. Earlier in the same session, registration worked correctly for three different users ( newuser@testco-qa.com ,  outsider@otherdomain.com ,  employee@readonlydomain.com ). After the server restart, registration consistently failed. This is likely a LiveView session mismatch issue — the browser's WebSocket session token became stale after the server restart, and the server is silently discarding the submit event. The "Reconnecting" WebSocket error shown in the  #client-error  flash (normally hidden) was observed immediately after restart. Impact: Scenarios 6b (post-disable enrollment check) and 7 could not be fully verified. Workaround: Quit and relaunch the browser entirely after a server restart to get a fresh LiveView session.

## Source

QA Story 427 — `.code_my_spec/qa/427/result.md`

## Triage Notes

Dismissed — expected Phoenix LiveView behavior after server restart (stale WebSocket session). Not a bug. QA plan already updated (qa-436) to note server restart requirement. Adding browser relaunch note to QA plan as part of the same improvement.
