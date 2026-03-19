# Flash message lost when revisiting an accepted or invalid invitation link

## Status

resolved

## Severity

medium

## Scope

app

## Description

When navigating to an invitation link that has already been accepted (or is otherwise invalid), the  accept.ex  LiveView mount redirects to  /  with  put_flash(:error, "This invitation link is invalid or has already been used.") . However, the error flash message does not appear on the destination page ( / ). The user is silently redirected to the home page with no feedback. Reproduction steps: Accept an invitation (the token is now consumed). Navigate again to  http://localhost:4070/invitations/{same-token} . Observe: browser lands on  http://localhost:4070/  with no visible flash message. Expected: error flash "This invitation link is invalid or has already been used." is visible on the home page after redirect. The code at  lib/metric_flow_web/live/invitation_live/accept.ex  lines 114–118 calls  put_flash  before  redirect(to: "/") . The flash may be lost because the home route ( / ) is a different LiveView that does not carry the flash from the previous socket. This may require using  Phoenix.LiveView.redirect  with flash carried in the session, or switching the destination to a route that processes the LiveView session flash correctly.

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`

## Resolution

Added flash message rendering to home.html.heex. The root route (/) is served by PageController which uses the root layout - that layout did not render flash messages. The invitation accept.ex LiveView correctly calls put_flash before redirect, and Phoenix LiveView's controller.ex correctly puts the flash into the Plug session on redirect. However, the home page template had no flash rendering. Fixed by adding <.flash kind={:info} flash={@flash} /> and <.flash kind={:error} flash={@flash} /> at the top of lib/metric_flow_web/controllers/page_html/home.html.heex. All 44 invitation LiveView tests pass and the full test suite shows only pre-existing unrelated failures.
