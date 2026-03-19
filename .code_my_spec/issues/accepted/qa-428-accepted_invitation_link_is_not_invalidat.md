# Accepted invitation link is not invalidated after first use

## Status

resolved

## Severity

high

## Scope

app

## Description

After accepting an invitation link, navigating back to the same  /invitations/{token}  URL renders the acceptance page again instead of showing an error. Clicking "Accept Invitation" a second time redirects to  /accounts  with the flash "You already have access to this account." — but this only succeeds because the user is already a member. The token itself is not invalidated. The expected behavior per AC6 is that a second visit to an accepted invitation link should show an error redirect with "invalid or has already been used." Instead, the page renders the full acceptance UI for an already-used token. Reproduced with token  PqjpWd178kK4c1-OdOBvG6Ks7tGSgE6JMdw1ZReNO3I  for  qa-member@example.com . The acceptance LiveView at  /invitations/:token  does not check whether the invitation has already been accepted before mounting. Evidence:  .code_my_spec/qa/428/screenshots/13_ac6_second_visit_accepted_link.png ,  .code_my_spec/qa/428/screenshots/14_ac6_second_accept_no_error.png

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`

## Resolution

Fixed by updating accept_invitation/2 in MetricFlow.Invitations to mark the invitation token as accepted (invalidate it) even when the user is already a member of the account. Previously, the :already_member check short-circuited before updating the invitation status, leaving it :pending and allowing the acceptance page to re-render. Now when a user is already a member, we call Repo.update(Invitation.accept_changeset(invitation)) before returning {:error, :already_member}, so subsequent visits to the same token URL receive {:error, :not_found} and are redirected with the correct error message. Files changed: lib/metric_flow/invitations.ex. Verified by running MIX_ENV=test mix agent_test - all 86 invitation tests pass.
