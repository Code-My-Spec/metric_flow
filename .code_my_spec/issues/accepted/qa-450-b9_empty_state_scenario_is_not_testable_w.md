# B9 empty-state scenario is not testable with current seeds — both QA users share account 2

## Severity

medium

## Scope

qa

## Description

The brief states that  qa-member@example.com  should have no insights and be suitable for testing the empty state on  /insights . In practice,  Accounts.get_personal_account_id/1  returns account 2 ("QA Test Account") for both  qa@example.com  and  qa-member@example.com  because both are members of the same account. Insights are scoped at the account level, so both users see the same 5 insights. To test the empty state, the seed strategy needs either: (a) a third user who is not a member of account 2 and whose first account has no insights, or (b) a dedicated empty-insights account seeded separately. The  qa_seeds_450.exs  script should be updated to create a new user/account pair with no insights, or  qa_seeds.exs  should ensure  qa-member@example.com  has a separate personal account.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`

## Resolution

Added a third QA user `qa-empty@example.com` with its own isolated personal account that has no insights seeded. This user can be used to test the empty state on `/insights`.

**Files changed:**
- `priv/repo/qa_seeds.exs` — Added `qa-empty@example.com` user creation via `QaSeed.find_or_create_user/3`, which auto-creates a separate personal account on registration
- `priv/repo/qa_seeds_450.exs` — Updated comments to document the empty-state testing strategy using `qa-empty@example.com`

**Verification:**
- `mix compile` — no errors
- `mix test` — 2270 tests, 39 failures (all pre-existing, no new regressions)
