# Invite form defaults to "owner" role when no explicit selection is made

## Severity

high

## Scope

app

## Description

When the invite form is submitted without explicitly interacting with the role select (i.e. the first option remains selected), the invited user receives the  owner  role. The first option in  select[name='invitation[role]']  is  owner . There is no default selection that would favor a safer role (e.g.,  read_only ). During testing, a re-invite was performed by filling only the email field and clicking "Invite" without changing the role select. The result was  qa-member@example.com  being added as an  owner , not  read_only . This was observed in the members list where both users showed role "owner". This is a UX safety issue: a user who does not notice the role select will accidentally grant owner-level access. The default first option in the invite roles list should be a lower-privilege role such as  read_only , or the form should require an explicit selection. Reproduction: Navigate to  /accounts/members  as owner Fill  input[name='invitation[email]']  with a valid user email Do not change the role select — leave it on its default value Click "Invite" Observe the invited user has  owner  role in the members list

## Resolution

Reordered the invite role lists in `AccountLive.Members` so `read_only` is the first (default) option instead of `owner`/`admin`. Both `@owner_invite_roles` and `@admin_invite_roles` now start with `read_only`.

### Files Changed

- `lib/metric_flow_web/live/account_live/members.ex` — reordered `@owner_invite_roles` and `@admin_invite_roles` to put `read_only` first

### Verification

- 88 tests in `test/metric_flow_web/live/account_live/` pass
- All Story 430 BDD spex pass
- No regressions in full spex suite for this story

## Source

QA Story 430 — `.code_my_spec/qa/430/result.md`
