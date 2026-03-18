# Triage Issues

You are triaging incoming QA issues at **medium+** severity.

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

## Critical (1)

- `2ddc1ae4-5865-49e5-9be6-d11ea6513fb6` — OAuth callback crashes with 500 on missing state parameter (critical)

## High (2)

- `4a152ded-b924-4d30-9722-c59acfda05eb` — Vibium cannot trigger phx-change on standalone LiveView inputs (high)
- `46db1d49-3e2a-4688-b2fd-0e339935216b` — Cancel link and not-found redirect use wrong path /dashboards (high)

## Medium (3)

- `3a4556f8-3b1c-4017-8636-038a87aee1c7` — Name validation error shown on fresh page load (medium)
- `dcefb5a4-4c30-4337-91e3-51e7446f0385` — Connected integration has no Reconnect button when provider is unconfigured (medium)
- `8ee937d5-e19a-4722-be5b-dbc33677f082` — OAuth error callbacks show flash message instead of dedicated error view (medium)

Stop the session when all issues have been triaged.
