# QA Result

Story 433 — Transfer Account Ownership

## Status

pass

## Scenarios

### Scenario A — Owner sees Transfer Ownership section

pass

1. Logged in as `qa@example.com` via the password form.
2. Navigated to `http://localhost:4070/accounts/settings`.
3. Page loaded without error.
4. Confirmed `[data-role='transfer-ownership']` is visible in the DOM.
5. Confirmed heading "Transfer Ownership" is present in the page.
6. Confirmed the "Transfer Ownership" submit button is visible.
7. The "New Owner" select dropdown lists all non-owner members.

Evidence: `.code_my_spec/qa/433/screenshots/owner_sees_transfer_section.png`

### Scenario B — Non-owner member does NOT see Transfer Ownership section

pass

1. qa-member@example.com was already a member of "QA Test Account" (no invitation needed).
2. Logged out as `qa@example.com` and logged in as `qa-member@example.com` / `hello world!`.
3. Navigated to `http://localhost:4070/accounts/settings`.
4. Confirmed `[data-role='transfer-ownership']` is NOT visible in the DOM (`browser_is_visible` returned false).
5. Confirmed "Transfer Ownership" text is NOT present in the page content.
6. Instead, a "Leave Account" section is shown for the non-owner member, which is the expected alternative.

Evidence: `.code_my_spec/qa/433/screenshots/member_no_transfer_section.png`

### Scenario C — Owner can perform ownership transfer

pass

1. Logged out as `qa-member@example.com` and logged in as `qa@example.com` (owner).
2. Navigated to `http://localhost:4070/accounts/settings`.
3. Located the Transfer Ownership form (`[data-role='transfer-ownership']`).
4. Selected `qa-member@example.com` (user_id=6) from the "New Owner" dropdown.
5. Clicked the "Transfer Ownership" button.
6. Flash message "Ownership transferred successfully" appeared immediately.
7. Confirmed `[data-role='transfer-ownership']` is no longer visible — original owner is now admin.
8. Logged out and logged in as `qa-member@example.com`.
9. Navigated to `http://localhost:4070/accounts/settings`.
10. Confirmed `[data-role='transfer-ownership']` IS visible — new owner now controls ownership.
11. The "New Owner" dropdown correctly lists `qa@example.com` (now demoted to admin) as a transferable option.

Evidence:
- `.code_my_spec/qa/433/screenshots/transfer_ownership_success.png` — flash message visible, section hidden
- `.code_my_spec/qa/433/screenshots/new_owner_sees_transfer_section.png` — new owner sees the section

### Scenario D — Unauthenticated access redirects

pass

1. Ran `curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/accounts/settings`.
2. Received HTTP `302` response — redirects to login as expected.

## Evidence

- `.code_my_spec/qa/433/screenshots/owner_sees_transfer_section.png` — owner's settings page with Transfer Ownership section visible
- `.code_my_spec/qa/433/screenshots/member_no_transfer_section.png` — member's settings page with no Transfer Ownership section (Leave Account shown instead)
- `.code_my_spec/qa/433/screenshots/transfer_ownership_success.png` — success flash after ownership transfer, section hidden for former owner
- `.code_my_spec/qa/433/screenshots/new_owner_sees_transfer_section.png` — new owner (qa-member) sees Transfer Ownership section after receiving ownership

## Issues

None
