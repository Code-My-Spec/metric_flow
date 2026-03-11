# qa-member@example.com has owner role on QA Test Account from prior QA sessions

## Severity

low

## Scope

qa

## Description

The seed script  priv/repo/qa_seeds_432.exs  detected that  qa-member@example.com  already has  owner  role on QA Test Account (not  read_only  as intended). This is a side effect of prior QA sessions where ownership was transferred. The script only checks for existing membership and skips the invite/accept flow — it does not validate or correct the existing role. As a result,  qa-member@example.com  cannot be used as the non-owner member test subject without a manual role correction or fresh user. A fresh user  qa-readonly@example.com  was registered and invited during this QA session to work around the issue. To fix: update  qa_seeds_432.exs  to verify the role matches  read_only  on existing membership, and use  Accounts.update_user_role/4  to demote to  read_only  if needed. Alternatively, document this limitation explicitly in the seed script comments.

## Source

QA Story 432 — `.code_my_spec/qa/432/result.md`
