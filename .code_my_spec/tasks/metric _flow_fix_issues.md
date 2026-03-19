# Fix Issues

You are fixing accepted QA issues at **medium+** severity.

## Tools

Use the following bash tools in `.code_my_spec/tools/issues/` to interact with issues:

- `.code_my_spec/tools/issues/get-issue <id>` — read full issue details
- `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` — mark as resolved with description of fix

## Goal

For each issue below:

1. **Understand the problem** — read the issue description and source QA result
2. **Fix the code** — use subagents (Agent tool) for the actual fix work. Group related issues
   into one subagent if they share a root cause. Each subagent should:
   - Read the relevant source files
   - Make the fix
   - Verify the fix works
3. **Resolve the issue** — run `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` with a summary of:
   - What was fixed
   - Files changed
   - How the fix was verified
4. **Run tests** after all fixes to verify nothing is broken: `mix test`

## Scope-Aware Fixing

Issues have a scope indicating what to fix:
- **app** — Fix application code (controllers, live views, schemas, etc.)
- **qa** — Fix QA infrastructure (seed scripts, auth scripts, QA plan, test tooling)
- **docs** — Fix documentation (specs, README, user stories)

Read the scope before fixing — a `qa` issue means the seeds or scripts need updating, not the app code.

## QA Context

- **QA plan:** `.code_my_spec/qa/plan.md` — server startup, seeds, auth strategy
- **QA results:** `.code_my_spec/qa/{story_id}/` — failed results, screenshots, briefs

Read the QA plan for how to start the server and run seeds if you need to verify fixes.
Read the failed result and screenshots for each issue's story to understand the reproduction.

## Unresolved Issues

## Scope: app (1)

### `qa-428-flash_message_lost_when_revisiting_an_acc.md` (ID: 3f50b411-a0c7-4518-a3ac-60ba8861c4a5)

**Source:** `.code_my_spec/qa/428/result.md`
**QA evidence:** `.code_my_spec/qa/428/`
- **Title:** Flash message lost when revisiting an accepted or invalid invitation link
- **Severity:** medium
- **Scope:** app
- **Story:** 428

When navigating to an invitation link that has already been accepted (or is otherwise invalid), the  accept.ex  LiveView mount redirects to  /  with  put_flash(:error, "This invitation link is invalid or has already been used.") . However, the error flash message does not appear on the destination page ( / ). The user is silently redirected to the home page with no feedback. Reproduction steps: Accept an invitation (the token is now consumed). Navigate again to  http://localhost:4070/invitations/{same-token} . Observe: browser lands on  http://localhost:4070/  with no visible flash message. Expected: error flash "This invitation link is invalid or has already been used." is visible on the home page after redirect. The code at  lib/metric_flow_web/live/invitation_live/accept.ex  lines 114–118 calls  put_flash  before  redirect(to: "/") . The flash may be lost because the home route ( / ) is a different LiveView that does not carry the flash from the previous socket. This may require using  Phoenix.LiveView.redirect  with flash carried in the session, or switching the destination to a route that processes the LiveView session flash correctly.

## Directory

Accepted issues: `.code_my_spec/issues/accepted/`

Fix the issues, resolve them with the tool, and run tests to verify.
