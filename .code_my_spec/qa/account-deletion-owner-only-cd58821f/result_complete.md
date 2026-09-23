# QA Result

## Status

pass

## Scenarios

### Scenario 1 — Owner sees the Danger Zone delete section

PASS

Logged in as `qa@example.com` (owner of QA Test Account) and navigated to
`http://localhost:4070/accounts/settings`. The "Delete Account" section with
`data-role="delete-account"` was visible. The heading "Delete Account" was
present in the danger zone card. The "Transfer Ownership" section
(`data-role="transfer-ownership"`) was also visible. The delete form contained
two inputs (account name confirmation, password) and a red "Delete Account"
button (`.btn-error`).

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-01-settings-page.png`

### Scenario 2 — Member (non-owner) does NOT see the delete section

PASS

Logged in as `qa-member@example.com` (admin role in QA Test Account) and
navigated to `http://localhost:4070/accounts/settings?account_id=20`. Neither
the `[data-role="delete-account"]` form nor the `[data-role="transfer-ownership"]`
form were visible. The page showed General Settings, Leave Account, and agency
configuration sections. The "Leave Account" section replaced the "Transfer
Ownership" / "Delete Account" sections for the non-owner member.

Note: The `account_id` URL param was required because the active account hook
defaults to the oldest account for qa-member ("Client Alpha"). The settings page
supports `?account_id=N` to override the active account — the members page does not.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-02-member-settings.png`

### Scenario 3 — Warning text is present before any interaction

PASS

Navigated to `http://localhost:4070/accounts/settings` as `qa@example.com`.
The warning paragraph inside `[data-role="delete-account"]` reads:

> "This action is permanent and cannot be undone. This deletion is irreversible
> — all account data, members, and integrations will be deleted."

Both "permanent" and "irreversible" are present in the warning text.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-03-danger-zone.png`

### Scenario 4 — Delete rejected when account name does not match

PASS

Filled `input[name="account_name_confirmation"]` with "Wrong Name", filled
`input[name="password"]` with `hello world!`, and clicked "Delete Account".
Flash error "Account name does not match" appeared. URL remained
`http://localhost:4070/accounts/settings`. Account was not deleted.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-04-wrong-name-flash.png`

### Scenario 5 — Delete rejected when password is incorrect

PASS

Filled `input[name="account_name_confirmation"]` with `QA Test Account` (exact
match), filled `input[name="password"]` with `WrongPassword123!`, and clicked
"Delete Account". Flash error "Incorrect password" appeared. URL remained
`http://localhost:4070/accounts/settings`. Account was not deleted.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-05-wrong-password-flash.png`

### Scenario 6 — Delete rejected when password is empty

PASS

Filled `input[name="account_name_confirmation"]` with `QA Test Account`, left
`input[name="password"]` empty, and clicked "Delete Account". Flash error
"Password is required" appeared. Account was not deleted.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-06-empty-password-flash.png`

### Scenario 7 — Successful account deletion redirects to accounts list

PASS

Navigated to settings as `qa@example.com` (owner). Screenshot taken before
deletion. Filled `input[name="account_name_confirmation"]` with `QA Test Account`
and `input[name="password"]` with `hello world!`. Clicked "Delete Account".

Result: Page redirected to `http://localhost:4070/accounts` with flash message
"Account deleted successfully." The accounts list showed "No accounts found."
confirming "QA Test Account" was removed.

Checked `/dev/mailbox` — 0 messages. No confirmation email is sent (this is
the expected and correct behavior per resolved issue qa-455). The flash message
"Account deleted successfully." is the correct post-fix message.

Screenshots:
- `.code_my_spec/qa/455/screenshots/scenario-07-before-deletion.png`
- `.code_my_spec/qa/455/screenshots/scenario-07-after-deletion.png`
- `.code_my_spec/qa/455/screenshots/scenario-07-mailbox.png`

### Scenario 8 — Member cannot access deleted account

PASS

After account deletion, logged in as `qa-member@example.com` and navigated to
`/accounts`. "QA Test Account" did NOT appear in the accounts list. Only the
member's other accounts (Client Alpha, Client Beta, Client Account Manager,
Client Read Only) were shown. All access grants were revoked for the member upon
account deletion.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-08-member-accounts-after-deletion.png`

### Scenario 9 — Owner cannot access settings of deleted account

PASS

After account deletion, logged in as `qa@example.com` and navigated to
`http://localhost:4070/accounts/settings`. The settings page redirected to
`http://localhost:4070/accounts` since qa@example.com had no accounts left.
The accounts list showed "No accounts found." The former owner cannot access
the settings of the deleted account.

Screenshot: `.code_my_spec/qa/455/screenshots/scenario-09-owner-after-deletion.png`

## Evidence

- `.code_my_spec/qa/455/screenshots/scenario-01-settings-page.png` — Owner view: full settings page with Danger Zone visible
- `.code_my_spec/qa/455/screenshots/scenario-02-member-settings.png` — Admin member view: settings page without Delete/Transfer sections
- `.code_my_spec/qa/455/screenshots/scenario-03-danger-zone.png` — Danger Zone section with warning text
- `.code_my_spec/qa/455/screenshots/scenario-04-wrong-name-flash.png` — Flash error: "Account name does not match"
- `.code_my_spec/qa/455/screenshots/scenario-05-wrong-password-flash.png` — Flash error: "Incorrect password"
- `.code_my_spec/qa/455/screenshots/scenario-06-empty-password-flash.png` — Flash error: "Password is required"
- `.code_my_spec/qa/455/screenshots/scenario-07-before-deletion.png` — Settings page before deletion with filled form
- `.code_my_spec/qa/455/screenshots/scenario-07-after-deletion.png` — Accounts list after deletion with success flash
- `.code_my_spec/qa/455/screenshots/scenario-07-mailbox.png` — Dev mailbox showing 0 messages (no email sent)
- `.code_my_spec/qa/455/screenshots/scenario-08-member-accounts-after-deletion.png` — Member's accounts list: no QA Test Account
- `.code_my_spec/qa/455/screenshots/scenario-09-owner-after-deletion.png` — Owner redirected to accounts list after deletion

## Issues

### Invite form role selection ignored — member added as owner instead of selected role

#### Severity
MEDIUM

#### Scope
APP

#### Description

When inviting `qa-member@example.com` to QA Test Account via
`http://localhost:4070/accounts/members`, selecting "admin" from the role
dropdown and clicking "Invite" resulted in the member being added with role
"owner" instead of "admin". The flash showed both "Member invited successfully"
and "Cannot demote the last owner" simultaneously, suggesting the invite
system added the user as owner and then attempted an automatic role demotion
that failed.

Reproduced: Navigate to `/accounts/members`, fill invite form with email
`qa-member@example.com`, select role "admin", click "Invite". Check the members
table — user appears as "owner" not "admin".

### Role change select fires on first user in DOM, not the user with matching hidden input

#### Severity
MEDIUM

#### Scope
APP

#### Description

On the members page (`/accounts/members`), the role change `<select>` elements
use `phx-change="change_role"` with a hidden `<input name="user_id">` inside
each form. When using browser automation (and potentially keyboard navigation),
selecting a value in any role select triggers `change_role` for the user
associated with that select's parent form. However, when using
`tr[data-role="member-row"][data-user-id="2"] select` as the CSS selector, the
first select found (for user_id=2, qa@example.com) was changed instead of the
intended user, accidentally demoting the owner.

This is both a UX issue (the form submits on change without confirmation) and a
testability concern. The `phx-change` fires without a separate submit button,
making accidental role changes easy to trigger.

### QA seed script fails due to Cloudflare tunnel conflict — no `--no-start` workaround works cleanly

#### Severity
LOW

#### Scope
QA

#### Description

Running `mix run priv/repo/qa_seeds.exs` fails when the Phoenix server is
running due to the Cloudflare tunnel GenServer. The QA plan documents a
`--no-start` workaround but it failed silently (no output, no data seeded). As
a result, QA Test Account had to be created manually via the browser UI, which
required additional setup steps (slug entry, membership invite) not described
in the brief.

The seed script should be verified to work with `--no-start` or an alternative
seed strategy (e.g., a mix task that starts only :repo dependencies) should be
documented.

Repro: Start the Phoenix server (`mix phx.server`), then run:
```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```
Result: Command completes with no output and produces no seed data.
