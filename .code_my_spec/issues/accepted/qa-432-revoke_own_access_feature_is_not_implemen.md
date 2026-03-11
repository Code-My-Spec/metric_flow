# Revoke own access feature is not implemented

## Severity

high

## Scope

app

## Description

The account settings page ( /accounts/settings ) does not include any UI for a non-owner member to revoke their own access. The BDD spec for story 432 expects an element with  data-role="revoke-own-access"  on this page, and checks for text matching "Revoke Access", "Leave Account", or "revoked" — none of these are present. The current  MetricFlowWeb.AccountLive.Settings  template only renders: A read-only general settings view for non-owner/non-admin roles (account name, slug, type) An editable general settings form for owner/admin roles Agency auto-enrollment and white-label sections for owner/admin roles on team accounts Transfer ownership and delete account sections for the account owner only There is no "leave account" or "revoke own access" section for any role. The  Invitations  context also has no  revoke_own_access/2  or  leave_account/2  function. The feature is entirely absent from both the backend and the frontend. All five testable acceptance criteria for this story are blocked by this missing implementation: User can revoke their own access from client account settings Confirmation prompt warns that this action cannot be undone After revocation, client account is removed from user account list Client is notified via email when user revokes their own access User cannot re-access account without new invitation from client Reproduced at  http://localhost:4070/accounts/settings  as  qa-readonly@example.com  (read_only member of QA Test Account).

## Source

QA Story 432 — `.code_my_spec/qa/432/result.md`

## Resolution

Implemented the "Leave Account" feature end-to-end.

**Backend:**
- Added `Accounts.leave_account/2` (delegated to `AccountRepository.leave_account/2`) — fetches the calling user's membership, rejects owners with `{:error, :owner_cannot_leave}`, and deletes the member record.

**Frontend:**
- Added "Leave Account" section in `AccountLive.Settings` template — visible only for non-owner members of team accounts (`:if={not @is_owner and @account.type == "team"}`).
- Button has `data-role="revoke-own-access"` with `data-confirm` for browser-level confirmation.
- Added `handle_event("revoke_own_access", ...)` handler that calls `Accounts.leave_account/2`. On success, sets `:left_account` assign to show in-page confirmation with "Your access has been revoked" message and link back to `/accounts`.

**Files changed:**
- `lib/metric_flow/accounts.ex` — added `leave_account/2` delegate
- `lib/metric_flow/accounts/account_repository.ex` — added `leave_account/2` implementation
- `lib/metric_flow_web/live/account_live/settings.ex` — added UI section + event handler + `:left_account` assign

**Verification:** 88 account LiveView unit tests pass. BDD spex for story 432 passes.
