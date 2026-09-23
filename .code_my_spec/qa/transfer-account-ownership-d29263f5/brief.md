# QA Story Brief

Story 433 — Transfer Account Ownership

## Tool

web (Vibium MCP browser tools)

## Auth

Run seeds first (see Seeds section), then log in via the Vibium MCP browser tools.

Login as the owner (qa@example.com):

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

To switch to the member user (qa-member@example.com), clear cookies and re-login:

```
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-out")
  -- OR clear cookies: mcp__vibium__browser_navigate then delete cookies
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa-member@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

## Seeds

Run the base QA seed script once before testing:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

This creates:
- Owner user: `qa@example.com` / `hello world!`
- Member user: `qa-member@example.com` / `hello world!`
- Team account: "QA Test Account" (qa@example.com is the owner)

For scenario B (non-owner cannot see Transfer Ownership section), the member must have account access. The seed creates qa-member@example.com but does NOT automatically add them to "QA Test Account". You will need to invite them during the test (see Scenario B steps below), OR create a story-specific seed that adds qa-member to the account.

Story-specific seed to add qa-member to QA Test Account as an admin:

```bash
mix run -e '
alias MetricFlow.{Accounts, Repo}
import Ecto.Query

owner = Accounts.get_user_by_email("qa@example.com")
member = Accounts.get_user_by_email("qa-member@example.com")
scope = MetricFlow.Scope.for_user(owner)

accounts = Accounts.list_accounts(scope)
account = Enum.find(accounts, &(&1.name == "QA Test Account"))

case Accounts.get_user_role(scope, member.id, account.id) do
  nil ->
    Accounts.add_account_member(scope, account.id, member.id, :admin)
    IO.puts("Added qa-member as admin to QA Test Account")
  role ->
    IO.puts("qa-member already has role: #{role}")
end
'
```

If the above inline command fails due to app module complexity, use the base seeds only and invite the member via the UI during Scenario B (the BDD spec does this via `/accounts/invitations`).

## What To Test

### Scenario A — Owner sees Transfer Ownership section

Maps to: AC1 (only owner can initiate), BDD scenario "owner sees the transfer ownership section on the settings page"

1. Log in as `qa@example.com` (the account owner).
2. Navigate to `http://localhost:4070/accounts/settings`.
3. Verify the page loads without error.
4. Scroll down to confirm a section with heading "Transfer Ownership" is present.
5. Verify the element `[data-role='transfer-ownership']` exists in the DOM.
6. Verify the button labeled "Transfer Ownership" is visible on the page.
7. Take a screenshot: `owner_sees_transfer_section.png`

Expected result: The Transfer Ownership form section is visible, including the "New Owner" select dropdown and the "Transfer Ownership" button.

### Scenario B — Non-owner member does NOT see Transfer Ownership section

Maps to: AC1 (only owner can initiate), BDD scenario "non-owner member does not see the transfer ownership section"

1. Log in as `qa@example.com` (the account owner).
2. Navigate to `http://localhost:4070/accounts/invitations`.
3. Invite `qa-member@example.com` with the role `admin` using the `#invite_member_form` form.
   - Fill `invitation[email]` with `qa-member@example.com`
   - Fill `invitation[role]` with `admin`
   - Submit the form
4. Accept the invitation — check the dev mailbox at `http://localhost:4070/dev/mailbox` for the invitation email and click the acceptance link, OR use the token-based acceptance URL shown in the mailbox.
5. Log out as owner and log in as `qa-member@example.com` / `hello world!`.
6. Navigate to `http://localhost:4070/accounts/settings`.
7. Verify the page loads without error.
8. Confirm the element `[data-role='transfer-ownership']` does NOT exist in the DOM.
9. Confirm the text "Transfer Ownership" is NOT present in the page content.
10. Take a screenshot: `member_no_transfer_section.png`

Expected result: The Transfer Ownership section is hidden for the admin/member role — only the General Settings section is visible.

### Scenario C — Owner can perform ownership transfer

Maps to: AC1, AC6 (upon acceptance, ownership transfers), AC7 (previous owner access changes)

Note: This scenario tests the full transfer flow. After transfer, the original owner is demoted to admin.

1. Log in as `qa@example.com` (owner).
2. Ensure `qa-member@example.com` is a member of the team account (complete Scenario B steps 1-4 first if needed).
3. Navigate to `http://localhost:4070/accounts/settings`.
4. Locate the Transfer Ownership form (`[data-role='transfer-ownership']`).
5. From the "New Owner" select dropdown, select `qa-member@example.com`.
6. Click the "Transfer Ownership" button.
7. Wait for a flash message.
8. Take a screenshot: `transfer_ownership_success.png`
9. Verify a success flash message appears containing "Ownership transferred successfully".
10. Verify the Transfer Ownership section is no longer visible (original owner is now admin).
11. Log out and log in as `qa-member@example.com`.
12. Navigate to `http://localhost:4070/accounts/settings`.
13. Verify the Transfer Ownership section IS now visible (qa-member is now the owner).
14. Take a screenshot: `new_owner_sees_transfer_section.png`

Expected result: Transfer completes with success flash. Original owner loses Transfer Ownership section access (demoted to admin). New owner gains the Transfer Ownership section.

### Scenario D — Unauthenticated access redirects

Maps to: general auth protection

1. Without logging in, navigate to `http://localhost:4070/accounts/settings`.
2. Use curl to check HTTP status: `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/settings`
3. Verify the response is `302` (redirect to login).

Expected result: Unauthenticated request redirects to the login page.

## Setup Notes

The BDD spec in `test/spex/433_transfer_account_ownership/criterion_4006_only_current_account_owner_can_initiate_ownership_transfer_spex.exs` tests that:
1. The owner sees `[data-role='transfer-ownership']` at `/accounts/settings`
2. A non-owner admin does NOT see `[data-role='transfer-ownership']`

The data-role attribute is on the `<form id="transfer-ownership-form">` element in the Settings LiveView. The section is rendered only when `@is_owner and @account.type == "team"`.

For Scenario B, the second user must have accepted their invitation to be a member before they can log in and view account settings. The dev mailbox at `http://localhost:4070/dev/mailbox` shows pending invitation emails.

After running the transfer in Scenario C, note that the seed data will be modified — re-run `mix run priv/repo/qa_seeds.exs` to reset ownership state before running the scenarios again.

## Result Path

`.code_my_spec/qa/433/result.md`
