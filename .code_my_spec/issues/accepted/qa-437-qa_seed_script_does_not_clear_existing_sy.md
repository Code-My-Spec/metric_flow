# QA seed script does not clear existing sync history for the QA user

## Status

resolved

## Severity

medium

## Scope

qa

## Description

Scenario 5 tests the empty state ("No sync history yet.") which is only shown when both  sync_history  and  sync_events  are empty. The brief states that after seeding, the QA owner user should have no sync history. However,  priv/repo/qa_seeds.exs  creates users and account records but does not delete any existing sync history for the QA user. On repeated QA runs (or after prior test scenarios that generated history), the  data_sync_history  (or equivalent) table retains entries for  qa@example.com , causing the empty state to be bypassed. To fix: add an idempotent cleanup step in  priv/repo/qa_seeds.exs  that deletes all sync history records scoped to the QA test user before re-seeding, so each QA run starts with a clean slate for empty-state tests. Reproduction: run  qa_seeds.exs  after any prior QA session that produced sync history entries, then navigate to  /integrations/sync-history  — the empty state panel is not shown.

## Source

QA Story 437 — `.code_my_spec/qa/437/result.md`

## Resolution

Added sync_history and sync_jobs cleanup step to priv/repo/qa_seeds.exs for clean slate on repeated QA runs.
