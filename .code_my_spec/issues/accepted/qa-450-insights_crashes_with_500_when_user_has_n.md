# /insights crashes with 500 when user has no account membership

## Status

resolved

## Severity

high

## Scope

app

## Description

When a user with no  account_members  records navigates to  /insights , the LiveView crashes with: ArgumentError: nil given for `account_id`. comparison with nil is forbidden as it is unsafe. AiRepository.list_insights/2  calls  Accounts.get_personal_account_id(scope)  which returns  nil  when the user has no account memberships. This nil is then passed directly to  where(account_id: ^account_id) , raising an ArgumentError instead of returning an empty list. The fix should nil-guard in  AiRepository.list_insights/2 : if  account_id  is nil, return  []  immediately. Alternatively,  get_personal_account_id/1  should be documented as possibly returning nil, and all callers should handle the nil case. Reproduced by logging in as  qa-empty@example.com  (a user with no account) and navigating to  http://localhost:4070/insights .

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`

## Resolution

Nil-guarded account_id in AiRepository.list_insights/2 and get_insight/2. When get_personal_account_id/1 returns nil (user has no account memberships), list_insights/2 now returns [] immediately and get_insight/2 returns {:error, :not_found} without executing any Ecto query. Fixed in lib/metric_flow/ai/ai_repository.ex. Verified by running MIX_ENV=test mix agent_test test/metric_flow/ai/ — 182 tests, 0 failures.
