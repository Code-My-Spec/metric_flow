# Invite form defaults to "owner" role when no explicit selection is made

## Status

resolved

## Severity

high

## Scope

app

## Description

When the invite form is submitted without explicitly interacting with the role select (i.e. the first option remains selected), the invited user receives the  owner  role. The first option in  select[name='invitation[role]']  is  owner . There is no default selection that would favor a safer role (e.g.,  read_only ). During testing, a re-invite was performed by filling only the email field and clicking "Invite" without changing the role select. The result was  qa-member@example.com  being added as an  owner , not  read_only . This was observed in the members list where both users showed role "owner". This is a UX safety issue: a user who does not notice the role select will accidentally grant owner-level access. The default first option in the invite roles list should be a lower-privilege role such as  read_only , or the form should require an explicit selection. Reproduction: Navigate to  /accounts/members  as owner Fill  input[name='invitation[email]']  with a valid user email Do not change the role select — leave it on its default value Click "Invite" Observe the invited user has  owner  role in the members list

## Source

QA Story 430 — `.code_my_spec/qa/430/result.md`

## Resolution

**Fix:** Reordered the `<select>` options in `lib/metric_flow_web/live/invitation_live/send.ex` so that `read_only` is the first option (and retains the `selected` fallback when no role param is present). Previously `admin` was listed first; the original QA report indicated `owner` was the first option at the time of testing. With `read_only` as the first option, even if the `selected` attribute is not applied correctly by the browser or LiveView DOM patching, the safest role is submitted by default.

**Files changed:**
- `lib/metric_flow_web/live/invitation_live/send.ex` — moved `read_only` option to first position in the role select

**Verification:** All 44 invitation LiveView tests pass.
