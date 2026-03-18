# QA database role drift: qa@example.com is admin instead of owner in QA Test Account

## Status

resolved

## Severity

medium

## Scope

qa

## Description

In the QA Test Account,  qa@example.com  holds the  admin  role instead of  owner .  qa-member@example.com  is currently the sole owner. This is the result of a previous test run (via the hidden  [data-role="change-role"]  button, which works correctly) that swapped the roles. The  qa_seeds.exs  script is idempotent but does not reset membership roles when users and accounts already exist. On repeated runs it skips the insert, leaving the mutated DB state in place. Impact: Scenarios 5 and 6 could not fully verify owner-exclusive behavior (invite at  owner  or  admin  role, full role select options). Fix: The seed script should delete and re-create QA Test Account membership records on each run to restore the expected roles ( qa@example.com  as  owner ,  qa-member@example.com  as  read_only ), or add a step that explicitly updates membership roles after the upsert.

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`

## Resolution

Added a "Reset Membership Roles" section (section 2a) to `priv/repo/qa_seeds.exs` that runs unconditionally after the team account is found or created. On every seed run it:

1. Ensures `qa-member@example.com` has a membership record in QA Test Account (inserts one as `:read_only` if missing).
2. Uses `Repo.update_all` to force `qa@example.com` to `:owner`.
3. Uses `Repo.update_all` to force `qa-member@example.com` to `:read_only`.

This means role drift from any previous QA test run is corrected before the next run begins, restoring the known-good baseline regardless of how many times the seeds have been executed.

**Files changed:**
- `priv/repo/qa_seeds.exs` — added section 2a (lines 99–143)

**Verification:**
- `mix test` passes with 2561 tests, 0 failures.
- The seed script logic was reviewed: `Repo.update_all` with a WHERE clause on `account_id` + `user_id` unconditionally sets the role column, so repeated runs always restore the expected roles.
