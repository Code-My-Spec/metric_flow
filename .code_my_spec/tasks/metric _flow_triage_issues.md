# Triage Issues

You are triaging incoming QA issues at **info+** severity.

## Tools

Use the following bash tools in `.code_my_spec/tools/issues/` to interact with issues:

- `.code_my_spec/tools/issues/list-issues --status incoming` — list all incoming issues
- `.code_my_spec/tools/issues/get-issue <id>` — read full issue details
- `.code_my_spec/tools/issues/accept-issue <id>` — accept a real issue
- `.code_my_spec/tools/issues/dismiss-issue <id> <reason>` — dismiss with a reason

## Goal

Review all incoming issues and decide their disposition.

1. **Read each issue** using `get-issue <id>` for the issues listed below
2. **Identify duplicates** — issues describing the same underlying problem
3. **Decide a disposition** for each issue:
   - **Accept** — real issue, run `.code_my_spec/tools/issues/accept-issue <id>`
   - **Dismiss** — not a real bug (test artifact, expected behavior, duplicate), run `.code_my_spec/tools/issues/dismiss-issue <id> "<reason>"`
   - **Merge** — accept the best issue, dismiss the others with a reason noting the duplicate
4. **Execute** each disposition using the tools above

## Incoming Issues

## High (2)

- `ef1bc40a-a878-4149-842b-df2751ffd4b9` — Sync failure flash message exposes raw Elixir tuple for Google sync exceptions (high)
- `202bd9b8-516f-4e51-8476-160be8a85330` — Google sync fails with database truncation error (string_data_right_truncation) (high)

## Medium (1)

- `98d4c007-b662-4c25-8bf9-715bb95fda20` — Sync Now button never enters disabled/loading state in practice (medium)

## Low (4)

- `0a53fa74-421b-46d9-b33f-cb875a82e46c` — Facebook sync fails with "All data providers failed" (low)
- `5611e218-5301-4f20-9a7a-0ed01294a941` — Sync Now disabled state not observable in dev environment (low)
- `cee0dbcb-d5ce-4ff0-8171-ec68c6c84eab` — Syncing badge and loading spinner not observable in dev (low)
- `3b900a20-f130-4d1f-9ecb-6d244cf637c1` — Sync failure flash message says "All data providers failed" — unclear to end users (low)

Stop the session when all issues have been triaged.
