# Validation errors shown on invitation form before user interacts

## Severity

medium

## Scope

app

## Description

When navigating to  /accounts/invitations , the invite form immediately shows "can't be blank" validation errors on both the email field and the role field, before the user has typed anything or submitted the form. This creates a confusing UX — the form appears pre-errored on arrival. Reproduced on initial page load as  qa@example.com  at  http://localhost:4070/accounts/invitations . The HTML shows  <p class="text-sm text-error mt-1">can't be blank</p>  rendered in both field wrappers with an empty changeset on mount. Root cause:  Invitations.change_invitation(scope, %{})  is being called with an empty params map that triggers validation — likely because the changeset runs  validate_required  on every  change_invitation  call regardless of whether it was user-triggered. Expected: no errors on initial mount, errors only after first submission attempt or field blur.

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`

## Resolution

Fixed by adding a new context function `blank_invitation_changeset/1` to `MetricFlow.Invitations` that returns an `%Ecto.Changeset{}` built with `Ecto.Changeset.change/1` (no cast, no validate_required). The mount in `send.ex` was updated to call this function instead of `change_invitation(scope, %{})`.

The post-submit reset (after a successful send) was also updated to use `blank_invitation_changeset/1` so the form returns to a clean error-free state after each sent invitation.

`change_invitation/2` was left unchanged — it still calls the full `Invitation.changeset/2` with validations, which is correct for the live-validation `handle_event "validate"` path.

Files changed:
- `lib/metric_flow/invitations.ex` — added `blank_invitation_changeset/1`
- `lib/metric_flow_web/live/invitation_live/send.ex` — mount and post-submit reset now call `blank_invitation_changeset/1`

Verification: `mix test test/metric_flow_web/live/invitation_live/send_test.exs` — all tests pass. The mount test confirms the form renders without validation errors. The validate and submit tests confirm errors are still shown after user interaction.
