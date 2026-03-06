# QA Result

Story 426: Multi-User Account Access
Component: MetricFlowWeb.AccountLive.Members
Tested: 2026-03-05 (updated 2026-03-06 after retry attempt)

## Status

partial

## Scenarios

### Scenario 1: Members page loads for authenticated owner

SKIPPED — vibium MCP server is not available in this environment. Browser-based
navigation and screenshot capture cannot be performed.

Covered by unit tests in `test/metric_flow_web/live/account_live/members_test.exs`
and BDD spex `criterion_3959_account_owner_can_view_all_users_in_their_account_with_their_access_levels_spex.exs`.
All unit tests pass (21/21). BDD spex pass (8/8).

### Scenario 2: Unauthenticated access redirects to login

PASS

Executed via curl:

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/members
```

Result: `302` — correct redirect to login page. Following the redirect lands on
the login page (HTTP 200). Authentication guard is working correctly.

### Scenario 3: Invite an existing user as a member

SKIPPED — vibium MCP server not available.

Covered by BDD spex `criterion_3955_account_owner_or_admin_can_invite_users_to_their_account_via_email_spex.exs` (PASS).
Unit test coverage in `members_test.exs` also validates invite behavior.

### Scenario 4: Invite a non-existent user shows error

SKIPPED — vibium MCP server not available.

Unit test and BDD spex exercise this code path. The `do_invite_member/3` private
function handles the `nil` case from `Users.get_user_by_email/1` and puts a
`"User not found"` flash error. All related tests pass.

### Scenario 5: Role selector shows all access levels for owner

SKIPPED — vibium MCP server not available.

Source code review confirms: `invite_roles(:owner)` returns
`~w(owner admin account_manager read_only member)` and `manageable_roles(:owner)`
returns `~w(owner admin account_manager read_only)`. The spec-required roles are
all present.

### Scenario 6: Invite a user as admin role

SKIPPED — vibium MCP server not available.

Covered by BDD spex `criterion_3957_users_can_have_different_access_levels_owner_admin_account_manager_read-only_spex.exs` (PASS).

### Scenario 7: Owner changes a member's role

SKIPPED — vibium MCP server not available.

Covered by BDD spex `criterion_3960_account_owner_or_admin_can_modify_user_access_levels_spex.exs` (PASS).
Unit test `permission_change: change_role` log line confirmed in test output.

### Scenario 8: Last owner cannot be demoted or removed

SKIPPED — vibium MCP server not available.

Source code review confirms the protection: `last_owner?/2` guards the
`[data-role="change-role"]` button (`:if={not last_owner?(member, @members)}`)
and the remove button (`:if={not last_owner?(...) and member.user_id != @current_scope.user.id}`).
Unit tests exercise this path. BDD spex `criterion_3958_access_levels_follow_hierarchy...` passes.

### Scenario 9: Remove a member from the account

SKIPPED — vibium MCP server not available.

Covered by BDD spex `criterion_3961_account_owner_or_admin_can_remove_users_from_the_account_spex.exs` (PASS).
The `permission_change: remove_member` log line was observed in unit test output, confirming
the event handler fires and the audit log entry is written.

### Scenario 10: Read-only member cannot see management controls

SKIPPED — vibium MCP server not available.

Source code review confirms: `can_manage?/1` returns `false` for `:read_only` role,
and the members table and invite form are both guarded by `:if={@can_manage}`. A
read-only user sees neither the invite form nor the action column.

### Scenario 11: Account-level isolation

SKIPPED — vibium MCP server not available.

Covered by BDD spex `criterion_3962_all_users_on_an_account_see_the_same_data_with_account-level_isolation_spex.exs` (PASS).
The `Accounts.list_account_members/2` call scopes queries through the user's Scope
struct, enforcing account-level isolation at the context layer.

## Evidence

- Scenario 2: HTTP 302 from `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/members`
- Unit tests: 21/21 passing — `mix test test/metric_flow_web/live/account_live/members_test.exs`
- BDD spex: 8/8 passing — all criterion files in `test/spex/426_multi-user_account_access/`

No browser screenshots were captured because the vibium MCP server is not configured
in this environment.

## Issues

### vibium MCP server not configured — browser scenarios cannot execute

#### Severity
HIGH

#### Scope
QA

#### Description
Both QA attempts (initial run 2026-03-05, retry run 2026-03-06) confirmed that all
`mcp__vibium__browser_*` tool calls return "No such tool available." The root cause
was identified: `~/Library/Application Support/Claude/claude_desktop_config.json`
has `"mcpServers": {}` — no MCP servers are registered at all.

As a result, all browser-based scenarios (1 and 3–11) cannot be executed and no
screenshots can be captured. The QA brief and plan both require vibium for all
LiveView UI testing.

Functional behavior was verified via `mix test` (21 unit tests, all pass) and
`mix spex` (8 BDD spex, all pass). However, the visual UI layer — role badge
rendering, form visibility toggling, flash messages, and the rendered HTML of the
members page in a real browser — was not verified.

To resolve: add the vibium MCP server to the Claude Code MCP configuration. The
entry in `claude_desktop_config.json` should look like:

```json
{
  "mcpServers": {
    "vibium": {
      "command": "npx",
      "args": ["-y", "@vibium/mcp-server"]
    }
  }
}
```

After adding it, restart Claude Code and re-run this QA story to complete the
browser-based scenarios and capture screenshots.
