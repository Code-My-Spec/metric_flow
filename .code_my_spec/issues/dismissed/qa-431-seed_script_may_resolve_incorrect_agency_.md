# Seed script may resolve incorrect agency account on re-run

## Severity

low

## Scope

qa

## Disposition

Dismissed — not an app bug. Documents a discovery about seed script ordering that has already been fixed. The script now queries directly by name and is idempotent.

## Description

The first version of  priv/repo/qa_seeds_story_431.exs  used  Accounts.list_accounts/1  with  Enum.find/2  to locate the agency account, which broke after grant propagation added qa@example.com as a member of client accounts (changing the list order). The script was fixed to query directly by name.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`
