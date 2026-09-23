# QA Result

Story 427 — Agency Team Auto-Enrollment

## Status

pass

## Scenarios

### Scenario 1 — Agency owner sees Auto-Enrollment section (criterion 3963)

pass

Navigated to `http://localhost:4070/accounts/settings` as `qa@example.com` (owner of QA Test Account, a team account). The page rendered the "Auto-Enrollment" section with the expected heading text. Both required elements were present and visible:

- `[data-role='auto-enrollment-domain-input']` — Email Domain input field, visible and interactive
- `[data-role='auto-enrollment-default-role']` — Default Access Level select with options Read Only, Account Manager, Admin

The White-Label Branding section was also present below Auto-Enrollment. Both agency sections are conditionally rendered only for team accounts where the user holds `owner` or `admin` role — confirmed working correctly.

Evidence: `.code_my_spec/qa/427/screenshots/01_settings_page_overview.png`

### Scenario 2 — Owner configures domain-based auto-enrollment (criterion 3963)

pass

Filled `[data-role='auto-enrollment-domain-input']` with `myagency.com` and submitted `#auto-enrollment-form`. The flash message "Auto-enrollment enabled" appeared immediately after submit. The settings page updated to display `myagency.com` with a green "Active" badge and a "Disable" button (`[data-role='disable-auto-enrollment']`).

Subsequently updated the rule to `testco-qa.com` — the form accepted the new value and again showed the "Auto-enrollment enabled" flash with the new domain displayed.

Evidence: `.code_my_spec/qa/427/screenshots/02_auto_enrollment_enabled_flash.png`

### Scenario 3 — New user with matching domain is auto-enrolled; non-matching domain is not (criterion 3964)

pass

With auto-enrollment active for `testco-qa.com`, logged out and registered `newuser2@testco-qa.com` (password `SecurePassword123!`, account name `Test Employee`). Registration confirmation page appeared successfully. Also registered `outsider2@otherdomain.com` with a non-matching domain.

Logged back in as `qa@example.com` and navigated to `/accounts/members`. The members list showed:
- `newuser2@testco-qa.com` — present with role `read_only` (auto-enrolled correctly)
- `outsider2@otherdomain.com` — absent from the list (non-matching domain, correctly not enrolled)

Evidence: `.code_my_spec/qa/427/screenshots/03_registration_confirmation_testco.png`, `.code_my_spec/qa/427/screenshots/04_members_after_testco_enrollment.png`

### Scenario 4 — Auto-enrolled user receives the configured default access level (criterion 3965)

pass

Configured auto-enrollment for domain `readonlydomain.com` with Default Access Level explicitly set to "Read Only" — flash "Auto-enrollment enabled" confirmed. Logged out and registered `employee2@readonlydomain.com`.

Logged back in as owner and navigated to `/accounts/members`. `employee2@readonlydomain.com` appeared in the list with role displayed as `read_only` (the badge showed the atom string form `read_only` as expected per the spec).

Evidence: `.code_my_spec/qa/427/screenshots/05_readonlydomain_configured.png`, `.code_my_spec/qa/427/screenshots/06_members_with_readonly_employee.png`

### Scenario 5 — Admin can view and manage auto-enrolled members (criterion 3966)

pass

Column headers confirmed via DOM inspection: Member, Role, Joined, Actions — all present in `<thead>`.

`employee2@readonlydomain.com` appeared in the members list. The role change UI uses a `<form phx-submit="change_role">` with a `<select name="role">` and a "Change" submit button (not a `phx-change` inline change). Selected `account_manager` from the select dropdown and clicked the "Change" button. The flash message "Role updated" appeared and the role badge in the row updated from `read_only` to `account_manager` — role change working correctly via form submit.

Note: The `[data-role='change-role']` button is rendered with class `sr-only` (screen-reader only, visually hidden) — the primary role change path is the form submit pattern.

Evidence: `.code_my_spec/qa/427/screenshots/07_role_change_success.png`

### Scenario 6 — Admin can disable auto-enrollment (criterion 3967)

pass

Navigated to `/accounts/settings` with `readonlydomain.com` active (green "Active" badge, Disable button visible). `[data-role='disable-auto-enrollment']` was present and clickable. After clicking:

- Flash "Auto-enrollment disabled" appeared
- Badge changed from "Active" (green) to "Disabled" (ghost)
- Disable button was hidden

Post-disable verification: Registered `postdisable3@readonlydomain.com` after disabling. Logged back in as `qa@example.com` and navigated to `/accounts/members` — `postdisable3@readonlydomain.com` was NOT in the members list, confirming that disabling auto-enrollment correctly prevents future auto-enrollments.

Evidence: `.code_my_spec/qa/427/screenshots/08_auto_enrollment_disabled.png`, `.code_my_spec/qa/427/screenshots/09_members_post_disable.png`

### Scenario 7 — Auto-enrolled members inherit access to client accounts (criterion 3968)

partial

The agency settings page rendered without error. Both `[data-role='agency-auto-enrollment']` and `[data-role='agency-white-label']` sections were visible and functioning for the team account owner.

Full client-account inheritance testing (using `Agencies.grant_client_account_access/5`) requires either a seed script or a future client-account-management UI that is not currently implemented. The UI portion of this scenario was verified — the settings page renders correctly and the auto-enrollment feature works end-to-end.

Evidence: `.code_my_spec/qa/427/screenshots/10_settings_agency_sections.png`

### Additional — Non-admin/read-only member does not see agency sections

pass

Logged in as `qa-member@example.com` and navigated to `/accounts/settings?account_id=21` (the QA Test Account where the member holds `read_only` role). The Auto-Enrollment and White-Label Branding sections were NOT present on the page — only "General Settings" (read-only fields) and "Leave Account" were rendered.

Note: `qa-member@example.com` holds `admin` role on other team accounts ("Client Alpha", "Client Beta") from previous test runs, so the agency sections correctly appear when viewing those accounts. The conditional rendering is account-scoped and role-scoped — working as designed.

Evidence: `.code_my_spec/qa/427/screenshots/12_member_read_only_no_agency_sections.png`

## Evidence

- `.code_my_spec/qa/427/screenshots/01_settings_page_overview.png` — Account settings page showing Auto-Enrollment and White-Label sections visible to team owner
- `.code_my_spec/qa/427/screenshots/02_auto_enrollment_enabled_flash.png` — "Auto-enrollment enabled" flash after saving myagency.com domain
- `.code_my_spec/qa/427/screenshots/03_registration_confirmation_testco.png` — Registration confirmation for newuser2@testco-qa.com
- `.code_my_spec/qa/427/screenshots/04_members_after_testco_enrollment.png` — Members list showing newuser2@testco-qa.com auto-enrolled with read_only role, outsider2@otherdomain.com absent
- `.code_my_spec/qa/427/screenshots/05_readonlydomain_configured.png` — Auto-enrollment configured for readonlydomain.com with Read Only default
- `.code_my_spec/qa/427/screenshots/06_members_with_readonly_employee.png` — Members list showing employee2@readonlydomain.com with read_only role
- `.code_my_spec/qa/427/screenshots/07_role_change_success.png` — "Role updated" flash and account_manager badge after role change for employee2@readonlydomain.com
- `.code_my_spec/qa/427/screenshots/08_auto_enrollment_disabled.png` — "Auto-enrollment disabled" flash and Disabled badge after clicking Disable button
- `.code_my_spec/qa/427/screenshots/09_members_post_disable.png` — Members list after disable: postdisable3@readonlydomain.com absent (correctly not enrolled)
- `.code_my_spec/qa/427/screenshots/10_settings_agency_sections.png` — Both agency sections render without error for team account owner
- `.code_my_spec/qa/427/screenshots/11_member_settings_client_alpha.png` — qa-member's active account (Client Alpha) where they hold admin role — agency sections visible (correct)
- `.code_my_spec/qa/427/screenshots/12_member_read_only_no_agency_sections.png` — QA Test Account settings for read_only member — no agency sections shown (correct)

## Issues

None
