# Accepted invitation link is not invalidated — acceptance page re-renders after use

## Severity

high

## Scope

app

## Description

After an invitee accepts an invitation, visiting the same invitation URL again renders the acceptance page as if the invitation were still pending. The "Accept Invitation" button is shown and can be clicked again. Steps to reproduce: Send an invitation to any email address Visit the acceptance URL  /invitations/{token} Click "Accept Invitation" — redirected to  /accounts Navigate back to the same URL Observation: the acceptance page renders again with "Accept Invitation" button The second click of Accept shows flash "You already have access to this account." and redirects — so there is a guard at the acceptance logic level. However the check does not happen at the route/mount level — the acceptance page always renders for any valid token, even already-accepted ones. Additionally, accepted invitations continue to appear in the owner's  /accounts/invitations  pending list, which means the pending count/list does not reflect the true state after acceptance. Expected behaviour (per AC6 and BDD spec): Visiting an accepted invitation URL should redirect with flash error "This invitation is invalid or has already been used." The invitation should be removed from the pending list after acceptance.

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`

## Resolution

Fixed in `lib/metric_flow_web/live/invitation_live/accept.ex`.

Added a guard clause in `mount/3` that matches on `accepted_at` being non-nil before the general `{:ok, invitation}` branch. When the token lookup returns an invitation that already has `accepted_at` set, the mount immediately redirects to `/` with the flash error "This invitation is invalid or has already been used." rather than rendering the acceptance page.

The pending invitation list was already filtered correctly — `InvitationRepository.list_invitations/2` queries with `status == :pending`, so accepted invitations (which have `status: :accepted` after `accept_invitation/2`) are automatically excluded. No change was needed there.

Files changed:
- `lib/metric_flow_web/live/invitation_live/accept.ex` — added `accepted_at` guard clause in `mount/3`

Verification: `mix test test/metric_flow_web/live/invitation_live/accept_test.exs` — 44 tests, 0 failures. The test "redirects to / with error flash when invitation has already been used" confirms the redirect and flash message.
