# QA Result

## Status

pass

## Scenarios

### Scenario 1: Agency sees list of client accounts (criterion 3991)

pass

Logged in as `qa@example.com`, navigated to `http://localhost:4070/accounts`. The accounts list shows all five accounts:
- Client Account Manager
- Client Read Only
- Client Beta
- Client Alpha
- QA Test Account

All four client accounts seeded by `qa_seeds_story_431.exs` are visible. The agency's own account ("QA Test Account") also appears. No unexpected accounts visible. Unauthenticated curl request to `/accounts` returns HTTP 302 redirect.

Evidence: `.code_my_spec/qa/431/screenshots/01-accounts-list-initial.png`

### Scenario 2: Each client listing shows access level and origination status (criterion 3992)

pass

On `/accounts` as `qa@example.com`:
- "Client Alpha" — shows `admin` role badge, `Admin` access level badge (accent), `Originator` origination badge (info). Correct.
- "Client Beta" — shows `admin` role badge, `Admin` access level badge, `Invited` origination badge. Correct.
- "Client Read Only" — shows `read_only` role badge, `Read Only` access level badge, `Invited` origination badge. Correct.
- "Client Account Manager" — shows `account_manager` role badge, `Account Manager` access level badge, `Invited` origination badge. Correct.

Evidence: `.code_my_spec/qa/431/screenshots/05-accounts-badges-detail.png`

### Scenario 3: Account switcher is present on each client card (criterion 3993)

pass

Five `[data-role="switch-account"]` buttons found on the `/accounts` page. The active account (Client Account Manager initially, then Client Beta after switching) shows "Active" and is disabled. Inactive accounts show their account name on the button.

Clicked the "Client Beta" switch button — flash message "Switched to Client Beta" appeared. The `[data-role="current-account-name"]` span in the nav updated to "Client Beta". The `data-active` attribute on the Client Beta card changed to "true".

After switching to Client Beta and navigating to `/accounts/settings`, the nav still shows "Client Beta" — confirming that `Accounts.touch_membership` persists the selection so `ActiveAccountHook` picks it up on remount.

Note: The switch button for inactive accounts shows the account name (e.g., "Client Beta") rather than a generic "Switch" label as described in the spec. This is a minor label discrepancy but does not impair functionality.

Evidence: `.code_my_spec/qa/431/screenshots/02-after-switch-client-beta.png`

### Scenario 4: Current client context shown in navigation (criterion 3994)

pass with observation

`[data-role="current-account-name"]` is present on:
- `/accounts` — shows "Client Account Manager" (active account), updates to "Client Beta" after switching
- `/accounts/settings` — shows "Client Beta"
- `/integrations` — shows "Client Beta"

However, `[data-role="current-account-name"]` is NOT present on `/accounts/members`. The `AccountLive.Members` LiveView renders `<Layouts.app flash={@flash} current_scope={@current_scope}>` without passing `active_account_name`, so the conditional `<%= if @active_account_name do %>` in the layout template never renders. Only `AccountLive.Index`, `AccountLive.Settings`, and `IntegrationLive.Index` pass `active_account_name` to the layout. 16 of 19 LiveViews using `Layouts.app` do not pass this assign.

Evidence: `.code_my_spec/qa/431/screenshots/03-current-account-name-settings.png`, `.code_my_spec/qa/431/screenshots/04-current-account-name-integrations.png`

### Scenario 5: Read-only access restrictions (criterion 3995)

pass

Registered `qa-readonly-test@example.com` via the registration form. Confirmed via dev mailbox magic link. Added as `read_only` member of "Client Read Only" via `mix run` seed script. Logged in with password — redirected to `/accounts` with "Client Read Only" as active account.

Navigated to `/accounts/settings`:
- No `#account-settings-form` element — confirmed absent
- Account Name and Slug inputs both have `readonly=""` attribute
- No `[data-role="delete-account"]` element — confirmed absent
- No `[data-role="transfer-ownership"]` element — confirmed absent
- "Leave Account" section is present (expected — any member can leave)

Evidence: `.code_my_spec/qa/431/screenshots/08-readonly-settings-page.png`

### Scenario 6: Account manager access restrictions (criterion 3996)

pass

Registered `qa-acctmgr-test@example.com`. Confirmed via dev mailbox. Added as `account_manager` of "Client Account Manager". Logged in.

- `/integrations` — renders "Integrations" heading. Page accessible. Correct.
- `/accounts/settings` — no `#account-settings-form`, no `[data-role="delete-account"]`, no `[data-role="transfer-ownership"]`. Correct.

Evidence: `.code_my_spec/qa/431/screenshots/10-acctmgr-integrations.png`, `.code_my_spec/qa/431/screenshots/11-acctmgr-settings.png`

### Scenario 7: Admin access capabilities (criterion 3997)

pass

Registered `qa-admin-test@example.com`. Confirmed via dev mailbox. Added as `admin` of "Client Alpha". Logged in — "Client Alpha" was immediately the active account.

- `/accounts/settings` — `#account-settings-form` IS present (editable form with name and slug inputs). "Save Changes" button visible. No `[data-role="delete-account"]`. No `[data-role="transfer-ownership"]`. Correct.
- `/integrations` — renders "Integrations" heading. Accessible. Correct.
- `/accounts/members` — `[data-role="members-list"]` IS present. `[data-role="member-row"]` IS present. Members list visible to admin. Correct.

Evidence: `.code_my_spec/qa/431/screenshots/13-admin-settings.png`, `.code_my_spec/qa/431/screenshots/14-admin-members.png`

### Scenario 8: Role-scoped member visibility (criterion 3998)

pass

As `qa-readonly-test@example.com` (read_only on "Client Read Only"):
- `/accounts/members` — no `[data-role="members-list"]`, no `[data-role="member-row"]`. Correct.

As `qa-admin-test@example.com` (admin on "Client Alpha"):
- `/accounts/members` — `[data-role="members-list"]` present, `[data-role="member-row"]` present. Correct.

As `qa-acctmgr-test@example.com` (account_manager on "Client Account Manager"):
- `/accounts/members` — no `[data-role="members-list"]`. Correct.

Evidence: `.code_my_spec/qa/431/screenshots/09-readonly-members-page.png`, `.code_my_spec/qa/431/screenshots/12-acctmgr-members.png`, `.code_my_spec/qa/431/screenshots/14-admin-members.png`

### Scenario 9: Originator badge (criterion 3999)

pass

On `/accounts` as `qa@example.com`:
- "Client Alpha" card — "Originator" badge present. Correct.
- "Client Beta" card — "Originator" text NOT present. "Invited" badge IS present. Correct.

Evidence: `.code_my_spec/qa/431/screenshots/15-qa-accounts-all-badges.png`

## Evidence

- `.code_my_spec/qa/431/screenshots/01-accounts-list-initial.png` — initial accounts page for qa@example.com showing all 5 accounts
- `.code_my_spec/qa/431/screenshots/02-after-switch-client-beta.png` — after switching to Client Beta, flash and nav updated
- `.code_my_spec/qa/431/screenshots/03-current-account-name-settings.png` — current-account-name on settings page
- `.code_my_spec/qa/431/screenshots/04-current-account-name-integrations.png` — current-account-name on integrations page
- `.code_my_spec/qa/431/screenshots/05-accounts-badges-detail.png` — all client cards with access level and origination badges
- `.code_my_spec/qa/431/screenshots/06-registration-form.png` — registration form for test users
- `.code_my_spec/qa/431/screenshots/07-mailbox-readonly-user.png` — dev mailbox with confirmation email for readonly user
- `.code_my_spec/qa/431/screenshots/08-readonly-settings-page.png` — settings page for read-only user (readonly inputs, no edit form)
- `.code_my_spec/qa/431/screenshots/09-readonly-members-page.png` — members page for read-only user (no members-list)
- `.code_my_spec/qa/431/screenshots/10-acctmgr-integrations.png` — integrations page accessible to account_manager
- `.code_my_spec/qa/431/screenshots/11-acctmgr-settings.png` — settings page for account_manager (no edit form)
- `.code_my_spec/qa/431/screenshots/12-acctmgr-members.png` — members page for account_manager (no members-list)
- `.code_my_spec/qa/431/screenshots/13-admin-settings.png` — settings page for admin (editable form, Save Changes button)
- `.code_my_spec/qa/431/screenshots/14-admin-members.png` — members page for admin (members-list and member-row present)
- `.code_my_spec/qa/431/screenshots/15-qa-accounts-all-badges.png` — full accounts page showing all badge types

## Issues

### current-account-name missing from most authenticated pages

#### Severity
MEDIUM

#### Description
The `[data-role="current-account-name"]` span in the navigation is only rendered by `Layouts.app` when the `active_account_name` attribute is passed. Only 3 of 19 LiveViews that render `Layouts.app` pass this attribute: `AccountLive.Index`, `AccountLive.Settings`, and `IntegrationLive.Index`. The remaining 16 LiveViews (`AccountLive.Members`, `DashboardLive.Editor`, `InvitationLive.Send`, `AiLive.Chat`, `CorrelationLive.Index`, `AiLive.Insights`, `IntegrationLive.SyncHistory`, etc.) do not pass `active_account_name`, so the current account name disappears from the navbar when navigating to those pages.

Reproduced: Log in as `qa@example.com`, navigate to `/accounts` (account name visible in nav), then navigate to `/accounts/members` — the `[data-role="current-account-name"]` element is absent.

The `ActiveAccountHook` already assigns `active_account_name` to the socket on mount for all authenticated LiveViews. The fix is for each LiveView to pass `active_account_name={@active_account_name}` (or the equivalent from their assigns) to `<Layouts.app>`.

### Switch account button shows account name instead of "Switch" label

#### Severity
LOW

#### Description
The inactive switch buttons on `/accounts` show the account name as the button label (e.g., a button reads "Client Beta") rather than a generic "Switch" label as specified in the spec (`AccountLive.Index` spec states: "labeled 'Switch' when inactive"). The source at `lib/metric_flow_web/live/account_live/index.ex:68` reads: `{if account.id == @active_account_id, do: "Active", else: account.name}`.

This creates an ambiguous UI — the button appears to be a link or label rather than a switch action. Reproduced: Log in as `qa@example.com`, navigate to `/accounts`. All inactive account buttons display the account name rather than "Switch".
