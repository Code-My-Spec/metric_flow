# QA Story Brief

Story 431: Agency Views and Manages Client Accounts

## Tool

web (vibium MCP browser tools)

## Auth

Log in as the agency owner using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait(selector: "body", timeout: 5000)
```

For scenarios that require a user with read-only, account_manager, or admin access to a *client* account (criteria 3995–3998), you must register a fresh user through the UI, then set up the account membership programmatically. Those scenarios use `AgenciesFixtures.account_with_member_fixture/2` in the BDD specs, which is only available in test context. For browser testing, create the test user via the `/users/register` form first, then use the dev mailbox to confirm the account before logging in.

To switch users during a session, clear cookies:

```
mcp__vibium__browser_delete_cookies()
```

Then navigate to `/users/log-in` and log in as the target user.

## Seeds

Run base seeds first, then the story-specific seeds:

```bash
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_story_431.exs
```

The story seeds create the following client accounts, all accessible to `qa@example.com` via QA Test Account (agency):

| Client Account Name      | Access Level    | Origination Badge |
|--------------------------|-----------------|-------------------|
| Client Alpha             | admin           | Originator        |
| Client Beta              | admin           | Invited           |
| Client Read Only         | read_only       | Invited           |
| Client Account Manager   | account_manager | Invited           |

For criteria 3995–3998 (role-specific access scenarios), you will need to register a new user, add them as a member to a client account via seeds or direct DB, then log in as that user. See Setup Notes below.

## What To Test

### Scenario 1: Agency sees list of client accounts (criterion 3991)

1. Log in as `qa@example.com`
2. Navigate to `http://localhost:4070/accounts`
3. Screenshot the page
4. Verify: "Client Alpha", "Client Beta", "Client Read Only", and "Client Account Manager" are all visible in the accounts list
5. Verify: "QA Test Account" (own account) also appears in the list
6. Verify: No accounts belonging to other users (not granted) appear

### Scenario 2: Each client listing shows access level and origination status (criterion 3992)

1. On the `/accounts` page as `qa@example.com`
2. Locate the "Client Alpha" card — verify it shows "admin" (or "Admin") access level AND "Originator" badge
3. Locate the "Client Beta" card — verify it shows "admin" access level AND "Invited" badge (no "Originator")
4. Locate the "Client Read Only" card — verify it shows "read_only" (or "Read Only") access level AND "Invited" badge
5. Locate the "Client Account Manager" card — verify it shows "account_manager" (or "Account Manager") access level AND "Invited" badge
6. Screenshot showing all client cards with their badges

### Scenario 3: Account switcher is present on each client card (criterion 3993)

1. On the `/accounts` page as `qa@example.com`
2. Verify: Each client account card has a `[data-role="switch-account"]` element (use `mcp__vibium__browser_find(selector: "[data-role='switch-account']")`)
3. Verify: The switch element contains the client account name (e.g., "Client Alpha")
4. Click the switch action for "Client Beta"
5. Verify: The UI reflects "Client Beta" as the active context (look for account name in page, active state on card)
6. Screenshot after switching

### Scenario 4: Current client context shown in navigation (criterion 3994)

1. On the `/accounts` page as `qa@example.com`
2. Verify: A `[data-role="current-account-name"]` element is present on the page
3. Navigate to `http://localhost:4070/accounts/settings`
4. Verify: `[data-role="current-account-name"]` is present
5. Navigate to `http://localhost:4070/integrations`
6. Verify: `[data-role="current-account-name"]` is present across pages
7. Screenshot showing the navigation element on at least one page

### Scenario 5: Read-only access restrictions (criterion 3995)

1. Register a new user: navigate to `http://localhost:4070/users/register`, register with a unique email (e.g., `qa-readonly-test@example.com`) and password `hello world!`, account name "Read Only Test"
2. Confirm the account via dev mailbox at `http://localhost:4070/dev/mailbox` — click the confirmation link
3. After confirmation, log in as the new user
4. Navigate to `http://localhost:4070/accounts/settings`
5. Verify: The account name input has the `readonly` attribute (`mcp__vibium__browser_get_attribute(selector: "input[name*='account']", attribute: "readonly")` or equivalent)
6. Verify: No `#account-settings-form` element is present
7. Verify: No "Delete Account" section (`[data-role="delete-account"]`) is present
8. Verify: No "Transfer Ownership" section (`[data-role="transfer-ownership"]`) is present
9. Screenshot the settings page

Note: The base registration creates a personal account where the user is the owner. To test read-only restrictions on a *client* account, the user needs to be added as a read-only member of a team account. This requires a seed step. Run:

```bash
# After registering qa-readonly-test@example.com in the UI, run:
mix run -e '
alias MetricFlow.{Users, Repo}
alias MetricFlow.Accounts.{Account, AccountMember}
user = Users.get_user_by_email("qa-readonly-test@example.com")
account = Repo.get_by!(Account, name: "Client Read Only")
%AccountMember{}
|> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: :read_only})
|> Repo.insert!(on_conflict: :nothing, conflict_target: [:account_id, :user_id])
IO.puts("Added read_only member")
'
```

Then log in as that user and navigate to `/accounts` — the "Client Read Only" account should appear. Navigate to `/accounts/settings` to verify read-only UI behavior.

### Scenario 6: Account manager access restrictions (criterion 3996)

1. Register `qa-acctmgr-test@example.com` / `hello world!`, account name "Account Manager Test"
2. Confirm the account via dev mailbox
3. Run seed to add as account_manager:

```bash
mix run -e '
alias MetricFlow.{Users, Repo}
alias MetricFlow.Accounts.{Account, AccountMember}
user = Users.get_user_by_email("qa-acctmgr-test@example.com")
account = Repo.get_by!(Account, name: "Client Account Manager")
%AccountMember{}
|> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: :account_manager})
|> Repo.insert!(on_conflict: :nothing, conflict_target: [:account_id, :user_id])
IO.puts("Added account_manager member")
'
```

4. Log in as `qa-acctmgr-test@example.com`
5. Navigate to `http://localhost:4070/integrations`
6. Verify: Page renders with "Integrations" heading and platform management options
7. Navigate to `http://localhost:4070/accounts/settings`
8. Verify: No `#account-settings-form` (read-only settings)
9. Verify: No "Delete Account" section
10. Verify: No "Transfer Ownership" section
11. Screenshot both pages

### Scenario 7: Admin access capabilities (criterion 3997)

1. Register `qa-admin-test@example.com` / `hello world!`, account name "Admin Test"
2. Confirm the account via dev mailbox
3. Run seed to add as admin:

```bash
mix run -e '
alias MetricFlow.{Users, Repo}
alias MetricFlow.Accounts.{Account, AccountMember}
user = Users.get_user_by_email("qa-admin-test@example.com")
account = Repo.get_by!(Account, name: "Client Alpha")
%AccountMember{}
|> AccountMember.changeset(%{account_id: account.id, user_id: user.id, role: :admin})
|> Repo.insert!(on_conflict: :nothing, conflict_target: [:account_id, :user_id])
IO.puts("Added admin member")
'
```

4. Log in as `qa-admin-test@example.com`
5. Navigate to `http://localhost:4070/accounts/settings`
6. Verify: `#account-settings-form` IS present (editable form)
7. Verify: "Save Changes" button is visible
8. Verify: No "Delete Account" section
9. Verify: No "Transfer Ownership" section
10. Navigate to `http://localhost:4070/integrations` — verify accessible
11. Navigate to `http://localhost:4070/accounts/members` — verify accessible with "Members" heading
12. Screenshot settings page showing the editable form

### Scenario 8: Agency cannot see other users unless admin (criterion 3998)

1. As `qa-readonly-test@example.com` (read-only), navigate to `http://localhost:4070/accounts/members`
2. Verify: No `[data-role="members-list"]` element
3. Verify: No `[data-role="member-row"]` element
4. Switch to `qa-admin-test@example.com` (admin), navigate to `http://localhost:4070/accounts/members`
5. Verify: `[data-role="members-list"]` IS present
6. Verify: At least one `[data-role="member-row"]` IS present
7. As `qa-acctmgr-test@example.com` (account_manager), navigate to `http://localhost:4070/accounts/members`
8. Verify: No `[data-role="members-list"]`
9. Screenshots for all three roles

### Scenario 9: Originator badge (criterion 3999)

1. Log in as `qa@example.com`, navigate to `http://localhost:4070/accounts`
2. Locate the "Client Alpha" card (admin + originator)
3. Verify: "Originator" text/badge is visible on that card
4. Locate the "Client Beta" card (admin + invited)
5. Verify: "Originator" text does NOT appear on Client Beta's card
6. Verify: "Invited" badge IS visible on Client Beta's card
7. Screenshot showing both cards with their distinct origination badges

## Setup Notes

The current `AccountLive.Index` source code (`lib/metric_flow_web/live/account_live/index.ex`) only uses `Accounts.list_accounts/1` and renders an "Owner" badge. It does not yet call `Agencies` context functions, does not render `data-role="switch-account"`, `data-role="account-card"`, `data-role="current-account-name"`, access level badges, or origination status badges. All BDD spec assertions about these elements are expected to fail until the implementation is updated. Record all failures as `app` scope issues.

The member-visibility scenarios (criterion 3998) check `[data-role="members-list"]` and `[data-role="member-row"]` on the `/accounts/members` page — also likely not yet implemented for role-scoped visibility.

The `/accounts/settings` role-gated UI (read-only input, no edit form, no delete section) is tested against `AccountLive.Settings`, not the Index — check that component's source if the settings page shows unexpected behavior.

For registering test users via the browser, `account_name` is required in the registration form. The form field is `name="user[account_name]"`.

## Result Path

`.code_my_spec/qa/431/result.md`
