# Story 447 seed script inserts data for wrong account when user has multiple team accounts

## Status

resolved

## Severity

medium

## Scope

qa

## Description

priv/repo/qa_seeds_447.exs  inserts correlation data into the account named
"QA Test Account" (hardcoded by name lookup). However,
 CorrelationsRepository.get_account_id/1  calls
 Accounts.get_personal_account_id/1 , which runs: from(m in AccountMember, where: m.user_id == ^user.id, select: m.account_id, limit: 1) This query has no  order_by  clause, so the database returns the first row by
insert order. For  qa@example.com , that is account_id=14 ("Client Alpha") —
inserted before "QA Test Account" (account_id=21) — regardless of which account
was seeded. As a result, after running  mix run priv/repo/qa_seeds_447.exs , the
 /correlations  page showed "No correlations match the selected filter." and
"0 data points" because the LiveView loaded data for account_id=14 (no data)
instead of account_id=21 (seeded data). The workaround used during this QA run was to manually insert the same seed data
directly into account_id=14 via a temporary script. To fix: update  priv/repo/qa_seeds_447.exs  to query the account_id that
 get_personal_account_id  will resolve to for  qa@example.com  at runtime
(i.e., the first  account_members  row by insert order for that user), rather
than looking up "QA Test Account" by name. Alternatively, update the seed to
use  Accounts.get_personal_account_id/1  directly via the Scope helper.

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`

## Resolution

Updated priv/repo/qa_seeds_447.exs to resolve the account_id using Accounts.get_personal_account_id(scope) via Scope.for_user/1 — the exact same call CorrelationsRepository makes at runtime — instead of hardcoding a lookup by team account name. This ensures seeded data lands in whichever account the LiveView will load for qa@example.com, regardless of account insert order. Added aliases for Accounts and Scope. Verified by running MIX_ENV=test mix agent_test (7 pre-existing unrelated failures, no new failures). File changed: priv/repo/qa_seeds_447.exs.
