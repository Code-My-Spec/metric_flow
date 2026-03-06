# QA Result

## Status

partial

## Scenarios

### Scenario 1 — Owner sees the Danger Zone delete section (criterion 4167, 4175)

**Result: pass (via unit test)**

Verified through `MetricFlowWeb.AccountLive.SettingsTest` — the test "shows the delete account section for account owners on team accounts" asserts `has_element?(lv, "[data-role='delete-account']")` and passes. The source template at `lib/metric_flow_web/live/account_live/settings.ex` confirms the `data-role="delete-account"` form is rendered under `@is_owner and @account.type == "team"`. The heading "Delete Account" is rendered with class `text-error`. The Transfer Ownership section is also confirmed present for owners via a corresponding passing test.

Browser-based screenshot evidence could not be captured — the vibium MCP browser tools were not available in this environment. See Issues section.

### Scenario 2 — Member (non-owner) does NOT see the delete section (criterion 4167, 4175)

**Result: pass (via unit test)**

Verified through the test "hides the delete account section for admin role" — asserts `refute has_element?(lv, "[data-role='delete-account']")` for a user with `:admin` role and passes. The test "hides the transfer ownership section for admin role" confirms the Transfer Ownership section is also hidden. The template conditionals `@is_owner and @account.type == "team"` enforce both sections are owner-only.

Browser-based multi-user flow (invite member then switch users) could not be executed without vibium MCP tools.

### Scenario 3 — Warning text is present before any interaction (criterion 4171)

**Result: pass (via source review)**

The source template at lines 203-205 of `settings.ex` renders the exact text: "This action is permanent and cannot be undone. This deletion is irreversible — all account data, members, and integrations will be deleted." This contains both "permanent" and "irreversible" as required by the acceptance criterion.

Screenshot evidence could not be captured.

### Scenario 4 — Delete rejected when account name does not match (criterion 4169)

**Result: pass (via unit test)**

Verified through the test "shows error flash when account name does not match" — submits `account_name_confirmation: "wrong name"` with a correct password and asserts `html =~ "Account name does not match"`. The test passes. The handler in `do_delete_account/3` at line 533 of `settings.ex` explicitly checks `name_confirmation != account.name` and returns the flash error before any further processing.

Browser screenshot of flash state could not be captured.

### Scenario 5 — Delete rejected when password is incorrect (criterion 4170)

**Result: pass (via unit test)**

Verified through the test "shows error flash when password is incorrect" — submits the correct account name with `password: "wrong-password-123"` and asserts `html =~ "Incorrect password"`. The test passes. The handler at line 539 of `settings.ex` calls `Users.get_user_by_email_and_password/2` and returns the "Incorrect password" flash when `nil` is returned.

### Scenario 6 — Delete rejected when password is empty (criterion 4170)

**Result: pass (via source review)**

The handler at lines 536-537 of `settings.ex` explicitly checks `is_nil(password) or password == ""` and returns `put_flash(socket, :error, "Password is required")` before attempting password verification. No dedicated unit test exists for the empty password case specifically, but the guard is present in the source and the behavior is covered by the logic path.

No browser screenshot captured.

### Scenario 7 — Successful account deletion redirects to accounts list with confirmation message (criterion 4169, 4170, 4172, 4174)

**Result: pass (via unit test)**

Verified through the test "owner can delete a team account with correct name and password" — submits the correct account name and valid password, and asserts `{:error, {:redirect, %{to: "/accounts"}}} = result`. The test passes. The handler at lines 543-548 of `settings.ex` calls `Accounts.delete_account/2` and on success redirects to `/accounts` with flash message "Account deleted. A confirmation email has been sent."

The dev mailbox check (`/dev/mailbox`) and the accounts list "QA Test Account not present" verification could not be done without browser tooling.

### Scenario 8 — Member cannot access deleted account (criterion 4172, 4173)

**Result: not tested**

This scenario requires the destructive deletion to have been performed in scenario 7, followed by a user switch to `qa-member@example.com` and navigating the accounts list. Both steps require the vibium MCP browser tools. The unit test "handles account deleted message and redirects to accounts list" covers the PubSub redirect behavior for the owner session, but the member-side access revocation in a live browser session was not tested.

### Scenario 9 — Owner cannot access settings of deleted account (criterion 4172)

**Result: pass (via unit test)**

Verified through the test "handles account deleted message and redirects to accounts list" — sends `{:deleted, account}` to the LiveView pid and asserts `assert_redirect(lv, "/accounts")`. The `handle_info/2` callback at lines 475-477 of `settings.ex` handles the `:deleted` message and redirects to `/accounts`.

## Evidence

No screenshots were captured in this session. The vibium MCP browser tools (`mcp__vibium__browser_*`) were not available — see Issues section.

The following test evidence is available:

- All 88 tests in `test/metric_flow_web/live/account_live/` pass (run confirmed via `mix test`)
- Source code at `lib/metric_flow_web/live/account_live/settings.ex` reviewed and confirmed aligned with acceptance criteria

## Issues

### Vibium MCP browser tools unavailable — browser-based QA scenarios could not execute

#### Severity
HIGH

#### Scope
QA

#### Description
The brief specifies that all UI testing for this story should use the vibium MCP browser tools (`mcp__vibium__browser_launch`, `mcp__vibium__browser_navigate`, etc.). When attempting to call `mcp__vibium__browser_launch`, the environment returned: "No such tool available: mcp__vibium__browser_launch".

As a result, none of the browser-based scenarios could be executed:
- No screenshots were captured for any scenario
- Scenario 2's multi-user flow (invite member, switch sessions) was not exercised in a real browser
- Scenario 7's destructive deletion was not run against the live app
- Scenario 8's post-deletion member access check was not performed
- The dev mailbox email confirmation check was not performed

All scenarios that could be verified were covered via `mix test` (unit/integration tests using `Phoenix.LiveViewTest`), and all 88 tests in `test/metric_flow_web/live/account_live/` pass. The feature implementation is correct based on source review and unit test coverage, but browser-based end-to-end evidence is absent.

To resolve: ensure the vibium MCP server is configured and running in the Claude Code MCP settings before executing browser-based QA stories. The QA plan at `.code_my_spec/qa/plan.md` documents the vibium setup but assumes the MCP server is already configured.
