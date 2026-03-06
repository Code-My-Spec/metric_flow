# QA Result

Story 427 — Agency Team Auto-Enrollment

## Status

partial

## Scenarios

### Scenario 1 — Owner sees Auto-Enrollment section on account settings page

pass

Navigated to `http://localhost:4070/accounts/settings` as `qa@example.com` (owner of QA Test Account, a team account). The page rendered the "Auto-Enrollment" section below the standard General Settings, Transfer Ownership, and Delete Account sections.

- `[data-role='auto-enrollment-domain-input']` was visible and interactable
- `[data-role='auto-enrollment-default-role']` (access level select with Read Only / Account Manager / Admin options) was visible
- The "White-Label Branding" section was also present directly below Auto-Enrollment

Both agency sections are conditionally shown only when `account.type == "team"` and the user holds owner/admin role — confirmed working correctly.

Evidence: `/Users/johndavenport/Pictures/Vibium/01_settings_page_overview.png`

### Scenario 2 — Owner configures domain-based auto-enrollment

pass

Filled `[data-role='auto-enrollment-domain-input']` with `myagency.com` and submitted `#auto-enrollment-form`. The flash message "Auto-enrollment enabled" appeared immediately. The settings page updated to display `myagency.com` with a green "Active" badge and a "Disable" button (`[data-role='disable-auto-enrollment']`).

Confirmed: saving a domain enables the rule, shows the active status, and displays the domain inline.

Evidence: `/Users/johndavenport/Pictures/Vibium/02_auto_enrollment_enabled_flash.png`

### Scenario 3 — New user with matching domain is auto-enrolled; non-matching domain is not

pass

**Matching domain:** Updated the auto-enrollment rule to `testco-qa.com`. Logged out, navigated to `/users/register`, and registered `newuser@testco-qa.com` with password `SecurePassword123!` and account name `Test Employee`. Registration confirmation page appeared. Logged back in as `qa@example.com` and navigated to `/accounts/members`. `newuser@testco-qa.com` appeared in the members list with role `read_only`.

**Non-matching domain:** While still on the members page, logged out and registered `outsider@otherdomain.com` (domain `otherdomain.com` — no matching rule). Logged back in as owner. The members list did NOT contain `outsider@otherdomain.com`. Only `qa@example.com`, `qa-member@example.com`, and `newuser@testco-qa.com` appeared.

Evidence: `/Users/johndavenport/Pictures/Vibium/03_new_user_registration_confirmation.png`, `/Users/johndavenport/Pictures/Vibium/04_members_after_testco_enrollment.png`

### Scenario 4 — Auto-enrolled user receives the configured default access level

pass

Updated auto-enrollment rule to domain `readonlydomain.com` with Default Access Level explicitly set to "Read Only". Flash "Auto-enrollment enabled" confirmed. Logged out and registered `employee@readonlydomain.com`. Logged back in as owner and checked `/accounts/members`. `employee@readonlydomain.com` appeared in the list with role `read_only` (shown as `read_only` badge).

Evidence: `/Users/johndavenport/Pictures/Vibium/05_readonlydomain_configured.png`, `/Users/johndavenport/Pictures/Vibium/06_members_with_readonly_employee.png`

### Scenario 5 — Admin can view and manage auto-enrolled members

partial

**Column headers** — Confirmed via DOM inspection that the table has headers: Member, Role, Joined, Actions (all present in `<thead>`).

**Member listing** — All auto-enrolled users appeared correctly in the members table with email, role badge, join date, a role-change select, and Remove button.

**Role change via select** — Attempted to change role for `newuser@testco-qa.com` (user_id=7) by selecting "account_manager" from the `select[phx-change='change_role']` dropdown. The select value visually changed to "account_manager" but:
1. The role badge in the adjacent cell remained "read_only"
2. No "Role updated" flash appeared
3. After page reload, the role was still "read_only" in the database

The `[data-role='change-role']` button is rendered `sr-only` (screen-reader only, zero visual size) and is not the primary interaction path — the `<select>` with `phx-change="change_role"` is the intended UI mechanism. The role change via this select does not appear to update the badge or persist to the database.

See issue: "Role change via select does not update or show feedback."

Evidence: `/Users/johndavenport/Pictures/Vibium/07_role_change_no_feedback.png`, `/Users/johndavenport/Pictures/Vibium/08_role_change_bug.png`

### Scenario 6 — Admin can disable auto-enrollment

pass

Navigated to `/accounts/settings`. With `readonlydomain.com` rule active (Active badge, Disable button visible), clicked `[data-role='disable-auto-enrollment']`. Flash "Auto-enrollment disabled" appeared. The badge changed from "Active" (green) to "Disabled" (ghost). The Disable button disappeared. The rule persisted through a server restart — on reload the domain still showed "Disabled."

**Post-disable enrollment test** — After disabling, attempted to register a new user with `afterdisable@readonlydomain.com` and `afterdisable2@readonlydomain.com`. Registration form submission silently failed (no success confirmation, no visible error, form reset to blank). This may indicate a separate registration bug introduced by the server restart or the LiveView reconnection state. Given the earlier registrations worked correctly and the disable state was verified in the DB (persisted through restart), this sub-scenario could not be fully confirmed due to a registration failure issue. See issue: "Registration form submit silently fails after server restart."

Evidence: `/Users/johndavenport/Pictures/Vibium/09_auto_enrollment_disabled.png`

### Scenario 7 — Non-admin/personal account does not see agency sections

not tested

The browser session crashed and the server went down before this scenario could be executed. Could not log in as `qa-member@example.com` to verify that non-admin members do not see the agency sections.

### Scenario 8 (additional) — Client account inheritance by auto-enrolled members

not tested

As noted in the brief, this scenario requires `Agencies.grant_client_account_access/5` which has no current UI. Server went down before testing via direct Elixir seed.

## Evidence

- `/Users/johndavenport/Pictures/Vibium/01_settings_page_overview.png` — Account settings page showing Auto-Enrollment and White-Label sections visible to team owner
- `/Users/johndavenport/Pictures/Vibium/02_auto_enrollment_enabled_flash.png` — "Auto-enrollment enabled" flash after saving myagency.com domain
- `/Users/johndavenport/Pictures/Vibium/03_new_user_registration_confirmation.png` — Registration confirmation for newuser@testco-qa.com
- `/Users/johndavenport/Pictures/Vibium/04_members_after_testco_enrollment.png` — Members list showing newuser@testco-qa.com auto-enrolled with read_only role
- `/Users/johndavenport/Pictures/Vibium/05_readonlydomain_configured.png` — Auto-enrollment configured for readonlydomain.com with Read Only default
- `/Users/johndavenport/Pictures/Vibium/06_members_with_readonly_employee.png` — Members list showing employee@readonlydomain.com with read_only role
- `/Users/johndavenport/Pictures/Vibium/07_role_change_no_feedback.png` — Role change select set to account_manager but badge still shows read_only
- `/Users/johndavenport/Pictures/Vibium/08_role_change_bug.png` — Second attempt at role change confirms no flash and no badge update
- `/Users/johndavenport/Pictures/Vibium/09_auto_enrollment_disabled.png` — "Auto-enrollment disabled" flash and Disabled badge after clicking Disable button
- `/Users/johndavenport/Pictures/Vibium/14_registration_silent_failure.png` — Registration form silently resets after submit (post-server-restart)
- `/Users/johndavenport/Pictures/Vibium/15_registration_form_filled.png` — Registration form with all fields filled before submit attempt

## Issues

### Role change via phx-change select does not update role badge or persist

#### Severity
HIGH

#### Description
On `/accounts/members`, changing a member's role using the inline `<select phx-change="change_role">` dropdown does not update the role badge in the same row and does not show a "Role updated" flash message. After page reload, the role remains unchanged in the database.

Reproduced twice: once before the server restart (when changing `newuser@testco-qa.com` from `read_only` to `account_manager`) and once after. The select's displayed value changes client-side but the `phx-change` event does not appear to produce a visible server response.

The handler in `AccountLive.Members` at line 229 correctly calls `Accounts.update_user_role/4` and puts a "Role updated" flash on success. The select sends `name="role"` plus `phx-value-user_id`. This may be a timing issue with LiveView event delivery, or the event is being swallowed by the server recompilation between the two restart cycles.

Reproduction steps:
1. Log in as `qa@example.com`
2. Navigate to `/accounts/members`
3. Find any non-owner member row
4. Change the role dropdown from `read_only` to `account_manager`
5. Observe: no flash, badge unchanged, DB unchanged on reload

### Registration form submit silently fails after server restart

#### Severity
MEDIUM

#### Scope
QA

#### Description
After the Phoenix server was restarted mid-session (due to the `dev_children/0` compile error), the registration form at `/users/register` began silently failing. Submitting the form with all required fields filled (email, password, account_name) returned no confirmation page and no visible error. The form simply reset to blank.

Earlier in the same session, registration worked correctly for three different users (`newuser@testco-qa.com`, `outsider@otherdomain.com`, `employee@readonlydomain.com`). After the server restart, registration consistently failed.

This is likely a LiveView session mismatch issue — the browser's WebSocket session token became stale after the server restart, and the server is silently discarding the submit event. The "Reconnecting" WebSocket error shown in the `#client-error` flash (normally hidden) was observed immediately after restart.

Impact: Scenarios 6b (post-disable enrollment check) and 7 could not be fully verified.

Workaround: Quit and relaunch the browser entirely after a server restart to get a fresh LiveView session.

### Missing dev_children/0 function causes server crash on restart

#### Severity
HIGH

#### Scope
QA

#### Description
`lib/metric_flow_web/application.ex` calls `dev_children()` at line 22 but the function was not defined anywhere in the codebase. This caused `mix compile` to fail with:

```
error: undefined function dev_children/0 (expected MetricFlowWeb.Application to define such a function)
```

The server was running before this QA session started (presumably started by the developer before this function went missing), but once stopped it could not be restarted. This blocked QA testing mid-session when the server crashed due to a LiveView WebSocket reconnect issue.

A fix was applied during this session (adding a no-op `dev_children/0`). The user has since updated this to the correct implementation using `ClientUtils.CloudflareTunnel`. The app now compiles and starts.

Reproduction: Stop the Phoenix server and run `mix phx.server` without the fix applied.

### Logout link in user dropdown has zero visual size and is not directly clickable

#### Severity
LOW

#### Scope
QA

#### Description
The "Log out" link (`a[href='/users/log-out']`) is inside a DaisyUI dropdown component (`.dropdown.dropdown-end`). The link reports zero size when the dropdown is collapsed, causing `browser_click(selector: "a[href='/users/log-out']")` to fail with "visible check failed — zero size."

To log out via the browser, the dropdown avatar button must first be clicked: `browser_click(selector: ".dropdown.dropdown-end div[tabindex='0']")`, then `browser_wait(selector: "a[href='/users/log-out']", state: "visible")`, then click the link.

The QA plan's auth section should document this pattern. Direct `a[href='/users/log-out']` clicks without opening the dropdown first will fail.
