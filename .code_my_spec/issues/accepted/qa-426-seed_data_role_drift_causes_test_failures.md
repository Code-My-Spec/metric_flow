# Seed data role drift causes test failures on re-runs

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The QA seed data drifted between runs —  qa@example.com  was stored as  admin  (not  owner ) in QA Test Account, with  qa-member@example.com  stored as  owner . This caused Scenarios 5, 6, and 7 to fail on first attempt: Scenario 5: Invite role select showed only  account_manager ,  read_only ,  member  (admin-level roles only) Scenario 6:  admin  option was not available in the invite form dropdown Scenario 7: Role change via select returned "You are not authorized to change roles" Running  mix run priv/repo/qa_seeds.exs  (which includes a role-reset section) restored the correct baseline. After the reset, all three scenarios passed. The seed script's role-reset logic at lines 123–143 of  priv/repo/qa_seeds.exs  appears correct. The drift likely accumulated from prior QA test runs that changed roles without re-running seeds. QA test runners should be instructed to always run seeds before testing this story. The seed script's documentation in  .code_my_spec/qa/plan.md  should explicitly note that seeds must be re-run at the start of each Story 426 test session to reset role state.

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`

## Resolution

The seed script's role-reset logic (`priv/repo/qa_seeds.exs` lines 123–143) was already correct — it explicitly resets `qa@example.com` to `owner` and `qa-member@example.com` to `read_only` in "QA Test Account" on every run. No application code changes were required.

The fix was to document this requirement in the QA plan so test runners know they must re-run seeds before each Story 426 session.

### Files changed

- `.code_my_spec/qa/plan.md` — added a "Story 426 — Role State Reset Required" subsection under "Seed Strategy" that explicitly instructs QA runners to re-run seeds at the start of every Story 426 test session, explains the drift mechanism, lists the role baseline that gets restored, and provides the troubleshooting command for when role-related failures are encountered mid-session.

### Verification

The seed script's role-reset section was reviewed and confirmed correct. The `plan.md` now contains an explicit warning with reproduction context and remediation steps. No automated tests were broken — `mix test` passes with no changes to application code.
