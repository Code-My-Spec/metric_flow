# QA Result

Story 426: Multi-User Account Access
Component: MetricFlowWeb.AccountLive.Members

## Status

pass

## Scenarios

### Scenario 1: Members page loads for authenticated owner

**Result: pass**

Navigated to `http://localhost:4070/accounts/members` as `qa@example.com`.

- Page heading "Members" (h1) is visible
- Subtitle shows "QA Test Account"
- `qa@example.com` appears in the members table with the `owner` role badge
- Six `[data-role="member-row"]` rows are present
- `#invite_member_form` is visible

Note: On first test run, seed data had drifted — `qa@example.com` was showing as `admin` and `qa-member@example.com` as `owner`. Running `mix run priv/repo/qa_seeds.exs` reset both to their correct baseline roles. All scenario results below reflect testing after the seed reset.

Evidence: `.code_my_spec/qa/426/screenshots/01_members_page_final.png`

### Scenario 2: Unauthenticated access redirects

**Result: pass**

```
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/members
```

Returned `302`. Correct redirect to login for unauthenticated access.

### Scenario 3: Invite an existing user as a member

**Result: pass**

Filled `input[name="invitation[email]"]` with `member-426@example.com` and selected `read_only` in `select[name="invitation[role]"]`. Clicked Invite.

- Flash "Member invited successfully" appeared
- `member-426@example.com` appeared in the members table with `read_only` badge

Evidence: `.code_my_spec/qa/426/screenshots/03_invite_success.png`

### Scenario 4: Invite a non-existent user shows error

**Result: pass**

Filled the invite form with `nobody-does-not-exist@example.com` and role `read_only`. Clicked Invite.

- Flash "User not found" appeared

Evidence: `.code_my_spec/qa/426/screenshots/04_invite_user_not_found_error.png`

### Scenario 5: Role selector shows all access levels for owner

**Result: pass**

After seeding to reset `qa@example.com` to owner:

- Invite form role select (`select[name="invitation[role]"]`) contained: `owner`, `admin`, `account_manager`, `read_only`, `member`
- Row-level `select[name="role"]` dropdowns were visible in the Actions column for each non-owner member row
- Each row-level select showed: `owner`, `admin`, `account_manager`, `read_only`

Evidence: `.code_my_spec/qa/426/screenshots/05_role_options_owner_corrected.png`

### Scenario 6: Invite a user as admin role

**Result: pass**

Removed `member-426@example.com` from account first, then invited them with role `admin`.

- Flash "Member invited successfully" appeared
- `member-426@example.com` row showed `admin` badge (`badge-secondary` class)

Evidence: `.code_my_spec/qa/426/screenshots/06_invite_as_admin.png`

### Scenario 7: Owner changes a member's role

**Result: pass**

Located the row-level select for `member-426@example.com` (last row). Changed value from `admin` to `read_only` via `phx-change="change_role"` form.

- Flash "Role updated" appeared
- `member-426@example.com` badge changed from `admin` to `read_only` (`badge-ghost` class)

Evidence: `.code_my_spec/qa/426/screenshots/07_role_change_select.png`

### Scenario 8: Last owner cannot be demoted or removed

**Result: pass**

With `qa@example.com` as the sole owner of QA Test Account:

- `[data-role="change-role"][data-user-email="qa@example.com"]` — not visible (`sr-only` button absent from DOM due to `last_owner?` guard)
- `[data-role="remove-member"][data-user-email="qa@example.com"]` — not visible (hidden by `:if` condition)

Evidence: `.code_my_spec/qa/426/screenshots/08_last_owner_protection.png`

### Scenario 9: Remove a member from the account

**Result: pass**

Clicked `[data-role="remove-member"][data-user-email="member-426@example.com"]`.

- Flash "Member removed" appeared
- `member-426@example.com` no longer appears in the members table

Evidence: `.code_my_spec/qa/426/screenshots/09_member_removed.png`

### Scenario 10: Read-only member cannot see management controls

**Result: pass**

Re-invited `member-426@example.com` as `read_only`, then logged in as `member-426@example.com`.

Navigated to `http://localhost:4070/accounts/members`:

- The members table (`[data-role="members-list"]`) is not rendered — the entire table section is hidden from `read_only` users via `:if={@can_manage}`
- `#invite_member_form` — not visible
- No `[data-role="change-role"]` buttons visible
- No `[data-role="remove-member"]` buttons visible
- Page shows only heading "Members" with subtitle "QA Test Account"

Evidence: `.code_my_spec/qa/426/screenshots/10_readonly_member_view.png`

### Scenario 11: Account-level isolation

**Result: pass**

While logged in as `member-426@example.com`, navigated to `http://localhost:4070/accounts/members`. The page shows QA Test Account context (the only account `member-426@example.com` belongs to). Since `member-426@example.com` is `read_only` in that account, no member list is rendered at all.

`qa@example.com`'s members list (verified separately while logged in as owner) shows only the 6 members of QA Test Account with no cross-account data bleed.

Evidence: `.code_my_spec/qa/426/screenshots/11_isolation_separate_account.png`

## Evidence

- `.code_my_spec/qa/426/screenshots/01_members_page_final.png` — Members page as owner (final state with correct roles)
- `.code_my_spec/qa/426/screenshots/01_members_page_owner.png` — Members page initial load (seed-drifted state showing qa@example.com as admin)
- `.code_my_spec/qa/426/screenshots/01_members_page_owner_corrected.png` — Members page after seed reset (qa@example.com as owner)
- `.code_my_spec/qa/426/screenshots/02_invite_form_visible.png` — Invite form visible on members page
- `.code_my_spec/qa/426/screenshots/03_invite_success.png` — "Member invited successfully" flash after inviting member-426@example.com
- `.code_my_spec/qa/426/screenshots/04_invite_user_not_found_error.png` — "User not found" error for nonexistent email
- `.code_my_spec/qa/426/screenshots/05_role_options_owner.png` — Role select with drifted admin role (missing owner/admin options)
- `.code_my_spec/qa/426/screenshots/05_role_options_owner_corrected.png` — Role select after seed reset showing all 5 options
- `.code_my_spec/qa/426/screenshots/06_invite_as_admin.png` — Successful invite as admin role
- `.code_my_spec/qa/426/screenshots/07_role_change_select.png` — Role updated flash after changing role via select
- `.code_my_spec/qa/426/screenshots/08_last_owner_protection.png` — Owner's row with no change-role or remove buttons
- `.code_my_spec/qa/426/screenshots/09_member_removed.png` — "Member removed" flash, member no longer in table
- `.code_my_spec/qa/426/screenshots/10_readonly_member_view.png` — Read-only member view: no table, no controls
- `.code_my_spec/qa/426/screenshots/11_isolation_separate_account.png` — member-426 scoped to own account context
- `.code_my_spec/qa/426/screenshots/12_already_member_error.png` — "User is already a member" error on duplicate invite

## Issues

### Seed data role drift causes test failures on re-runs

#### Severity
MEDIUM

#### Scope
QA

#### Description
The QA seed data drifted between runs — `qa@example.com` was stored as `admin` (not `owner`) in QA Test Account, with `qa-member@example.com` stored as `owner`. This caused Scenarios 5, 6, and 7 to fail on first attempt:

- Scenario 5: Invite role select showed only `account_manager`, `read_only`, `member` (admin-level roles only)
- Scenario 6: `admin` option was not available in the invite form dropdown
- Scenario 7: Role change via select returned "You are not authorized to change roles"

Running `mix run priv/repo/qa_seeds.exs` (which includes a role-reset section) restored the correct baseline. After the reset, all three scenarios passed.

The seed script's role-reset logic at lines 123–143 of `priv/repo/qa_seeds.exs` appears correct. The drift likely accumulated from prior QA test runs that changed roles without re-running seeds. QA test runners should be instructed to always run seeds before testing this story. The seed script's documentation in `.code_my_spec/qa/plan.md` should explicitly note that seeds must be re-run at the start of each Story 426 test session to reset role state.
