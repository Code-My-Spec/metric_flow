# POST /users/log-in with email-only body returns HTTP 500

## Status

accepted

## Severity

low

## Scope

app

## Description

Sending  POST /users/log-in  with  user[email]  but no  user[password]  field returns
HTTP 500. The controller's  create/3  clause at line 34 of  user_session_controller.ex 
pattern-matches with  %{"email" => email, "password" => password} = user_params , which
raises a  MatchError  when  "password"  is absent from the map. In normal browser usage this path is never reached: the magic link form uses
 phx-submit="submit_magic"  which is handled by the LiveView process and never POSTs to
the controller. However a direct HTTP POST to the endpoint (e.g. from a script or
malformed request) crashes rather than returning a graceful 400 or redirecting with an
error flash. To reproduce: curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:4070/users/log-in \
  -b <session-cookies> \
  -d "_csrf_token=<valid-token>&user[email]=qa@example.com"
# Returns: 500 Fix: add a catch-all  create/3  clause or guard that handles the email-only case gracefully.

## Source

QA Story 425 — `.code_my_spec/qa/425/result.md`
