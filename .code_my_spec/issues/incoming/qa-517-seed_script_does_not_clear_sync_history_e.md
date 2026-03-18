# Seed script does not clear sync history — empty state cannot be tested via browser

## Status

incoming

## Severity

low

## Scope

qa

## Description

The standard QA seed script ( priv/repo/qa_seeds.exs ) does not truncate or clear the  sync_history  table. After multiple QA runs, the seeded account accumulates sync history entries, making it impossible to test the empty state ( [data-role="sync-history"]  showing "No sync history yet.") via browser automation. The empty state is verified by the BDD spec suite instead, but the brief states it should be testable via browser. A story-specific seed or a seed script that clears sync history for the QA account would allow browser-based empty state testing. Workaround: The BDD specs in  test/spex/517_*/  create isolated test processes that start with no history and test the empty state path.

## Source

QA Story 517 — `.code_my_spec/qa/517/result.md`
