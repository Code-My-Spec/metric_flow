# QA Result

Story 431: Agency Views and Manages Client Accounts

## Status

fail

## Scenarios

### Scenario 1: Agency sees list of client accounts (criterion 3991)

**Result: partial pass**

Navigated to `http://localhost:4070/accounts` as `qa@example.com`. The page rendered all 5 accounts: "Client Alpha", "Client Beta", "Client Read Only", "Client Account Manager", and "QA Test Account". All seeded client accounts are visible in the list, which satisfies the basic listing requirement.

However, the accounts appear because the QA seed's `grant_client_account_access` call propagated qa@example.com as an AccountMember on each client account — not because the Index LiveView reads agency grants. The `AccountLive.Index` source only calls `Accounts.list_accounts/1`, which returns all accounts where the user is a member regardless of type. The intent of the spec (agency-specific display with access level context) is not implemented.

Evidence: `.code_my_spec/qa/431/screenshots/01-accounts-page-owner.png`

### Scenario 2: Each client listing shows access level and origination status (criterion 3992)

**Result: fail**

All five account cards display only a hardcoded "Owner" badge and the text "Originator: qa@example.com". No access level badges (Admin, Account Manager, Read Only) are rendered. No origination status badges ("Originator" or "Invited") are rendered. The `AccountLive.Index` template does not call `Agencies` context functions and does not conditionally render agency-specific badges.

Expected: Client Alpha shows "admin" + "Originator"; Client Beta shows "admin" + "Invited"; Client Read Only shows "read_only" + "Invited"; Client Account Manager shows "account_manager" + "Invited".
Actual: All cards show "Owner" + "Originator: qa@example.com".

Evidence: `.code_my_spec/qa/431/screenshots/01-accounts-page-owner.png`

### Scenario 3: Account switcher is present on each client card (criterion 3993)

**Result: fail**

No `[data-role="switch-account"]` elements exist anywhere on the accounts page. The account cards have no switch button, no `phx-click="switch_account"` handler, no `data-active` attribute on cards, and no `data-role="account-card"`. The feature is entirely absent from the implementation.

`mcp__vibium__browser_is_visible(selector: "[data-role='switch-account']")` returned `false`.

Evidence: `.code_my_spec/qa/431/screenshots/01-accounts-page-owner.png`

### Scenario 4: Current client context shown in navigation (criterion 3994)

**Result: fail**

Checked `[data-role="current-account-name"]` on `/accounts`, `/accounts/settings`, and `/integrations`. The element was not found on any page. The navigation bar contains only the MetricFlow logo, nav links, theme toggle, and user avatar dropdown — no current account name indicator.

`mcp__vibium__browser_is_visible(selector: "[data-role='current-account-name']")` returned `false` on all three pages.

Evidence: `.code_my_spec/qa/431/screenshots/03-integrations-page.png`

### Scenario 5: Read-only access restrictions on settings (criterion 3995)

**Result: partial pass / partial fail**

Logged in as `qa-431-readonly@example.com` (read_only member on "Client Read Only").

Settings page (`/accounts/settings`) observations:
- `input[readonly]` IS present — account name input is correctly read-only. PASS.
- `#account-settings-form` is NOT present — no editable form. PASS.
- `[data-role='delete-account']` is NOT present. PASS.
- `[data-role='transfer-ownership']` is NOT present. PASS.

However, the account settings page is showing "Client Read Only" correctly for this user (the active account is the one with the most recent membership, which happens to be correct here). The read-only input behavior appears to be working correctly for this role.

The `/accounts/members` page shows the full members list including all user emails — this violates criterion 3998 (see Scenario 8).

Evidence: `.code_my_spec/qa/431/screenshots/05-settings-readonly-user.png`, `.code_my_spec/qa/431/screenshots/06-members-readonly-user.png`

### Scenario 6: Account manager access restrictions (criterion 3996)

**Result: partial pass / partial fail**

Logged in as `qa-431-acctmgr@example.com` (account_manager member on "Client Account Manager").

Integrations page (`/integrations`):
- Page accessible. PASS.
- "Integrations" heading visible. PASS.
- "Connect a Platform" / "Available Platforms" visible. PASS.

Settings page (`/accounts/settings`):
- `input[readonly]` IS present. PASS.
- `#account-settings-form` NOT present. PASS.
- `[data-role='delete-account']` NOT present. PASS.
- `[data-role='transfer-ownership']` NOT present. PASS.

Members page (`/accounts/members`):
- Full members list IS visible (all 5 member emails shown with account_manager role). FAIL — account manager should not see the member list per criterion 3998.
- `[data-role='members-list']` NOT present. FAIL (missing data attribute).
- `[data-role='member-row']` NOT present. FAIL (missing data attributes).

Evidence: `.code_my_spec/qa/431/screenshots/07-integrations-acctmgr.png`, `.code_my_spec/qa/431/screenshots/08-settings-acctmgr.png`, `.code_my_spec/qa/431/screenshots/09-members-acctmgr.png`

### Scenario 7: Admin access capabilities (criterion 3997)

**Result: partial pass / partial fail**

Logged in as `qa-431-admin@example.com` (admin member on "Client Alpha").

Settings page (`/accounts/settings`):
- `#account-settings-form` IS present. PASS.
- "Save Changes" button IS visible. PASS.
- `[data-role='delete-account']` NOT present. PASS.
- `[data-role='transfer-ownership']` NOT present. PASS.

Integrations page (`/integrations`): Accessible with content. PASS.

Members page (`/accounts/members`): Members list IS visible with Change/Remove actions for all 5 members. PASS that admin can see members. However `[data-role='members-list']` and `[data-role='member-row']` attributes are NOT present — the BDD spec assertions for these data attributes will fail. FAIL.

Evidence: `.code_my_spec/qa/431/screenshots/10-settings-admin.png`, `.code_my_spec/qa/431/screenshots/11-members-admin.png`

### Scenario 8: Agency cannot see other users without admin access (criterion 3998)

**Result: fail**

- **Read-only user** navigated to `/accounts/members`: Full member list visible (5 members with emails, roles, joined dates). Should not be visible. FAIL.
- **Account manager user** navigated to `/accounts/members`: Full member list visible (5 members). Should not be visible. FAIL.
- **Admin user** navigated to `/accounts/members`: Full member list visible with Change/Remove controls. Admin CAN see it. PASS (behavior correct, but missing `data-role` attributes).

In all three cases, `[data-role='members-list']` and `[data-role='member-row']` selectors returned false — these attributes are not implemented.

Evidence: `.code_my_spec/qa/431/screenshots/06-members-readonly-user.png`, `.code_my_spec/qa/431/screenshots/09-members-acctmgr.png`, `.code_my_spec/qa/431/screenshots/11-members-admin.png`

### Scenario 9: Originator badge (criterion 3999)

**Result: fail**

On the `/accounts` page as `qa@example.com`:
- "Originator" text does NOT appear as a badge for Client Alpha (which has `is_originator: true`). FAIL.
- "Invited" badge does NOT appear for Client Beta. FAIL.
- All cards uniformly show "Owner" badge and "Originator: qa@example.com" text (hardcoded from `@current_scope.user.email`), making no distinction between originated and invited relationships.

Evidence: `.code_my_spec/qa/431/screenshots/01-accounts-page-owner.png`

## Evidence

- `.code_my_spec/qa/431/screenshots/01-accounts-page-owner.png` — Accounts page as qa@example.com: all 5 accounts shown, all with "Owner" badge and hardcoded originator email
- `.code_my_spec/qa/431/screenshots/02-accounts-settings-owner.png` — Settings page as qa@example.com (active account resolved to "Client Account Manager" due to list ordering)
- `.code_my_spec/qa/431/screenshots/03-integrations-page.png` — Integrations page showing no current-account-name element in nav
- `.code_my_spec/qa/431/screenshots/04-accounts-page-readonly-user.png` — Accounts page as read-only user: shows "Client Read Only" with "Owner" badge
- `.code_my_spec/qa/431/screenshots/05-settings-readonly-user.png` — Settings page as read-only user: read-only inputs, no edit form, no delete/transfer sections
- `.code_my_spec/qa/431/screenshots/06-members-readonly-user.png` — Members page as read-only user: full member list exposed (bug)
- `.code_my_spec/qa/431/screenshots/07-integrations-acctmgr.png` — Integrations page as account manager: accessible
- `.code_my_spec/qa/431/screenshots/08-settings-acctmgr.png` — Settings page as account manager: read-only inputs, no edit form
- `.code_my_spec/qa/431/screenshots/09-members-acctmgr.png` — Members page as account manager: full member list exposed (bug)
- `.code_my_spec/qa/431/screenshots/10-settings-admin.png` — Settings page as admin: editable form with Save Changes, no delete/transfer
- `.code_my_spec/qa/431/screenshots/11-members-admin.png` — Members page as admin: full member list with Change/Remove controls
- `.code_my_spec/qa/431/screenshots/12-accounts-page-final.png` — Final accounts page view confirming no switch-account or agency-specific elements

## Issues

### AccountLive.Index does not display agency access level or origination status badges

#### Severity
HIGH

#### Description
The `/accounts` page renders all accounts the user is a member of but shows only a hardcoded "Owner" badge and the user's own email as "Originator" for every card. The implementation does not call `MetricFlow.Agencies` context functions, does not distinguish between own accounts and client accounts accessed via agency grants, and does not render access level badges ("Admin", "Account Manager", "Read Only") or origination status badges ("Originator", "Invited").

All accounts the user is an AccountMember of appear identically regardless of their actual role or relationship type. Criteria 3992 and 3999 fail entirely.

Reproduction: Log in as `qa@example.com`, navigate to `http://localhost:4070/accounts`. Observe "Client Alpha" (agency admin, originator) and "Client Beta" (agency admin, invited) are displayed identically.

Source: `lib/metric_flow_web/live/account_live/index.ex`

### AccountLive.Index missing switch-account controls and data-role attributes

#### Severity
HIGH

#### Description
The accounts page has no `[data-role="switch-account"]` elements, no `phx-click="switch_account"` event handler, no `data-role="account-card"` attributes on cards, and no `data-active` attribute on cards. The account context switching feature (criterion 3993) is entirely absent.

The spec at `.code_my_spec/spec/metric_flow_web/account_live/index.spec.md` documents these as required: each account card should have `data-role="account-card"` and a `[data-role="switch-account"]` button. None of these are implemented.

Reproduction: Log in, navigate to `/accounts`. Inspect DOM — no `data-role` attributes on account cards.

### Navigation missing current-account-name indicator

#### Severity
HIGH

#### Description
No `[data-role="current-account-name"]` element exists in the navigation on any authenticated page (`/accounts`, `/accounts/settings`, `/integrations`). The spec requires the nav to clearly display which account is currently active. The navigation bar contains only the logo, nav links, theme toggle, and user avatar — no account context indicator.

Criterion 3994 fails entirely.

Reproduction: Log in, navigate to any authenticated page. Inspect DOM for `[data-role="current-account-name"]` — not found.

### Read-only and account_manager users can see the full members list

#### Severity
HIGH

#### Description
Users with `read_only` or `account_manager` roles on a client account can navigate to `/accounts/members` and see the complete list of all member emails, roles, and join dates. Per criterion 3998, only users with admin access should see the members list.

- `qa-431-readonly@example.com` (read_only on "Client Read Only"): members list fully visible with 5 member records including emails.
- `qa-431-acctmgr@example.com` (account_manager on "Client Account Manager"): members list fully visible with 5 member records.

Additionally, none of the member rows or the members list container have `data-role="members-list"` or `data-role="member-row"` attributes, so even if role-gating were added, the BDD spec selectors would still fail.

Reproduction: Log in as `qa-431-readonly@example.com` / `hello world!`, navigate to `http://localhost:4070/accounts/members`. Full member list is visible.

Evidence: `.code_my_spec/qa/431/screenshots/06-members-readonly-user.png`

### Members list and member rows missing data-role attributes

#### Severity
MEDIUM

#### Description
The `AccountLive.Members` page renders the members list and member rows without `data-role="members-list"` or `data-role="member-row"` attributes. The BDD specs for criteria 3997 and 3998 assert the presence or absence of these selectors.

Even for the admin user (where the members list IS correctly shown), the selectors `[data-role='members-list']` and `[data-role='member-row']` return false because the attributes do not exist in the rendered HTML.

Reproduction: Log in as `qa-431-admin@example.com` / `hello world!`, navigate to `/accounts/members`. Inspect DOM — no `data-role` attributes on member list container or rows.

### Active account defaults to most-recently-joined account instead of primary account

#### Severity
MEDIUM

#### Description
When `qa@example.com` (the agency owner) logs in, their "active" account resolves to "Client Account Manager" — the most recently created client account — rather than their own "QA Test Account". This is because `Accounts.list_accounts/1` orders by `account_members.inserted_at DESC`, and the grant propagation step added qa@example.com as a member of the client accounts most recently.

The account settings page shows "Client Account Manager" as the active account for the owner, and the owner has no edit form there (they have account_manager role on that account). The owner cannot easily access their own account's settings.

This is a systemic issue: without an explicit account-switching mechanism (criterion 3993), users with multiple account memberships are stuck with whatever account the list ordering puts first.

Reproduction: Run both seed scripts, log in as `qa@example.com`, navigate to `/accounts/settings`. Observe "Client Account Manager" shown as active instead of "QA Test Account".

Evidence: `.code_my_spec/qa/431/screenshots/02-accounts-settings-owner.png`

### Seed script may resolve incorrect agency account on re-run

#### Severity
LOW

#### Scope
QA

#### Description
The first version of `priv/repo/qa_seeds_story_431.exs` used `Accounts.list_accounts/1` with `Enum.find/2` to locate the agency account, which broke after grant propagation added qa@example.com as a member of client accounts (changing the list order). The script was fixed to query directly by name. However this reveals that the app's default account selection logic is order-dependent and fragile.

The fixed script at `priv/repo/qa_seeds_story_431.exs` uses a direct Ecto query by name ("QA Test Account") and is idempotent. No action needed on the script itself — this issue is filed to document the discovery.
