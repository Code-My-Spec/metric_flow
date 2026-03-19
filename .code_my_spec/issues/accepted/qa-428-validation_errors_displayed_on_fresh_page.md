# Validation errors displayed on fresh page load without user interaction

## Status

resolved

## Severity

medium

## Scope

app

## Description

When navigating to  /accounts/invitations  for the first time, the invite form immediately shows two "can't be blank" validation error messages — one for the email field and one for the role field — before the user has touched any input. This is caused by  Invitations.change_invitation(scope, %{})  in  mount_for_role/4  producing a changeset with errors that are immediately rendered by the template. The form's  form_has_error?/2  helper returns true for both fields since the changeset validates required fields even on empty params. The fix should suppress validation errors on the initial mount (e.g., using  action: nil  on the changeset, or tracking a  touched  state that enables error display only after the first submit or change event). Reproduced by navigating to  http://localhost:4070/accounts/invitations  as  qa@example.com  on any fresh page load. Evidence:  .code_my_spec/qa/428/screenshots/01_invitations_page_initial.png ,  .code_my_spec/qa/428/screenshots/21_fresh_page_validation_errors.png

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`

## Resolution

Fixed by updating build_invitation_form/3 in MetricFlowWeb.InvitationLive.Send to accept a show_errors boolean flag. On initial mount, the form is built with show_errors: false, so validation errors from the changeset are not exposed to the template. After the user interacts (validate event on change, or send_invitation submit), the form is rebuilt with show_errors: true, showing errors only when relevant. Also reset to show_errors: false after a successful send to give a clean empty form. Files changed: lib/metric_flow_web/live/invitation_live/send.ex. Verified by running MIX_ENV=test mix agent_test - all 86 invitation tests pass with no warnings.
