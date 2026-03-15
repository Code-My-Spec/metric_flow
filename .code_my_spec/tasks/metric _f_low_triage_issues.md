# Triage Issues

You are triaging incoming QA issues at **medium+** severity.

## Tools

Use the following bash tools to interact with issues:

- `list-issues --status incoming` — list all incoming issues
- `get-issue <id>` — read full issue details
- `accept-issue <id>` — accept a real issue
- `dismiss-issue <id> <reason>` — dismiss with a reason

## Goal

Review all incoming issues and decide their disposition.

1. **Read each issue** using `get-issue <id>` for the issues listed below
2. **Identify duplicates** — issues describing the same underlying problem
3. **Decide a disposition** for each issue:
   - **Accept** — real issue, run `accept-issue <id>`
   - **Dismiss** — not a real bug (test artifact, expected behavior, duplicate), run `dismiss-issue <id> "<reason>"`
   - **Merge** — accept the best issue, dismiss the others with a reason noting the duplicate
4. **Execute** each disposition using the tools above

## Incoming Issues

## Medium (1)

- `0cf6e1d4-ed55-49d5-a1bd-5f11df49e180` — google_ads integration seed cannot be run while server is active (medium)

Stop the session when all issues have been triaged.
