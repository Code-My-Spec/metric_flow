# Qa Story Brief — Story 32: Account Deletion (Owner Only)

## Tool

web

## Auth

App base URL: http://127.0.0.1:59302

Login page: `http://127.0.0.1:59302/users/log-in` — use the `#login_form_password` form
(email + password fields, submit button inside that form). Dev mailbox at
`http://127.0.0.1:59302/dev/mailbox` for confirmation emails and invitation links.

Seeded owner: `qa@example.com` / `hello world!` — used only as a secondary
login to confirm nothing in QA Test Account was disturbed. Do NOT delete
QA Test Account — it is shared fixture data for many other stories.

This story is destructive (account deletion), so all primary testing uses a
fresh, disposable team account registered during this session rather than
the shared QA Test Account.

## Seeds

No base seed script needed beyond what's already in the running dev DB
(confirms `qa@example.com` exists). Register fresh users directly through
the UI for this story's disposable fixtures:

- Register a fresh agency/team account as the owner, e.g.
  `qa32-owner-<timestamp>@example.com`, account type "Agency", account name
  "QA32 Delete Co". Confirm via the magic-link in `/dev/mailbox`.
- Register a second fresh user, e.g. `qa32-member-<timestamp>@example.com`,
  and invite them into "QA32 Delete Co" via `/app/accounts/members` at
  `account_manager` role (needed for criterion 273/551 — a non-owner role
  that can edit settings but must not see/be able to delete).
- Register a third fresh user as a `read_only` member of the same account,
  to confirm the Danger Zone is absent for that role too.
- Before deleting the account, as the owner: connect at least one
  integration-like fixture or confirm the owner's `qa@example.com`-style
  personal data model — since integrations/metrics/dashboards in this app
  are scoped by `user_id`, not `account_id` (see Setup Notes), use the
  owner's own pre-existing personal metrics/integrations if any exist, or
  note their absence and test via code-level DB confirmation instead.

## What To Test

- **265/541**: Log in as the fresh account's owner, navigate to
  `/app/accounts/settings` (or `?account_id=<id>` for the right account).
  Confirm the "Delete Account" danger-zone card is visible.
- **273/551, admin-can't-delete**: Log in as the `account_manager` member
  (closest role to "admin" that still has `can_edit`). Visit the same
  settings page — confirm the Danger Zone card is **absent**. Also confirm
  the `read_only` member doesn't see it either.
- **266/542, originator-no-longer-owner**: As the original owner, use
  "Transfer Ownership" to hand ownership to the account_manager member.
  Re-load settings as the (now ex-owner, now admin) original user — confirm
  the Danger Zone is gone for them, even though `originator_user_id` on the
  account still points to them. If direct form submission is feasible
  (e.g. via `browser_evaluate` to re-show the form), confirm the server
  still rejects it (`{:error, :unauthorized}` → flash "You are not
  authorized to delete this account"). Then transfer ownership back to the
  original owner for the remaining scenarios.
- **267/543/544, name confirmation**: As owner, fill the delete form with
  an incorrect account name (e.g. "wrong name") and a correct password.
  Submit — confirm deletion does NOT happen (reload settings, account still
  there) and check what error/behavior appears (the handler code only checks
  password server-side — confirm whether name mismatch is actually enforced
  anywhere, client or server; if not enforced, that's a finding).
- **268/545/546, password re-entry**: Fill correct account name, wrong
  password. Submit — confirm flash "Incorrect password" and account still
  exists. Then correct name + correct password in a final run (see below).
- **269/547, permanence warning**: Confirm the visible warning text ("This
  action is permanent and cannot be undone...") renders on the Danger Zone
  card before any deletion attempt.
- **270/548, account data removed**: Before final deletion, note the owner's
  `user_id` and check (via DB, since the UI has no direct metrics/reports/
  integrations list scoped to this disposable account) whether this user has
  any `integrations`/`metrics`/`dashboards` rows. After deletion, re-check
  the same rows. Given `lib/metric_flow/accounts/account_repository.ex`'s
  `run_delete_account_transaction/1` only deletes `AccountMember` rows and
  the `Account` row itself, and `integrations`/`metrics`/`dashboards` are
  schema-scoped by `user_id` (not `account_id`, confirmed in
  `priv/repo/migrations/*create_integrations*`, `*create_metrics*`,
  `*create_dashboards*`), expect these to survive deletion untouched —
  confirm this live rather than assuming.
- **271/549, access grants revoked**: With the account_manager and
  read_only members still attached, perform the final deletion as owner.
  Log in as each member afterward and confirm the account no longer appears
  in `/app/accounts` and their old membership is gone (this is DB-cascaded
  via `AccountMember` delete_all in the same transaction — confirm live).
- **272/550, confirmation email**: After deletion, check `/dev/mailbox` for
  an email to the owner's address confirming the deletion, matching the
  account name.
- **Final deletion flow**: As owner, fill the correct account name and
  correct password, submit. Confirm redirect to `/app/accounts`, and that
  the deleted account doesn't appear there or at `/app/accounts/settings`.

## Result Path

.code_my_spec/qa/32/result.md

## Setup Notes

Code read ahead of testing, to target the live checks precisely:

- `MetricFlowWeb.AccountLive.Settings` gates the whole Danger Zone card on
  `@is_owner and @account.type in [:client, :agency]` — `@is_owner` comes
  from `Accounts.get_user_role/3 == :owner`, a pure role check, not
  `originator_user_id`. `MetricFlow.Accounts.Authorization.permitted?/3`
  independently enforces `:owner`-only for the `:delete_account` action
  server-side, so both the originator and admin/non-owner scenarios should
  be correctly blocked by construction — verify live rather than trust this
  reading alone.
- **UPDATE (retest after fix for issue 1c6090ec, commit a777e06):**
  `AccountRepository.delete_account/2` now also calls `delete_all_metrics/1`,
  `delete_all_integrations/1`, `delete_all_dashboards/1` (+ `delete_all_visualizations/1`),
  all scoped by the *owner's user_id*, inside the same transaction as the
  member/account deletes. Known limitation (accepted): a user who owns more
  than one account loses ALL their metrics/integrations/dashboards on
  deleting any one of them, since these tables still have no `account_id`.
  For this retest, use a brand-new disposable owner who owns only the one
  throwaway account, so this limitation doesn't confound the result.
- Criterion 270/548's own BDD spex (`criterion_270_...spex.exs`) never
  actually checks metrics/reports/integrations — it only asserts the
  deleted account disappears from the accounts list and settings page.
  Verify the real fix live via direct DB rows, not just the spex passing.
- `extract_delete_params/1` (settings.ex ~L724) reads `account_name` from
  either `delete_confirmation[account_name]` (BDD) or flat
  `account_name_confirmation` (unit tests). Use whichever matches the real
  rendered form field name — the visible input is `account_name_confirmation`
  (flat), per the template (~L282).
