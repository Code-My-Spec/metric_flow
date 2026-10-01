# Qa Story Brief

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

- Owner: `qa@example.com` / `hello world!` (owns "QA Test Account")
- Member: `qa-member@example.com` / `hello world!` (read_only on "QA Test Account")

Use `.code_my_spec/qa/scripts/login.sh` / `logout.sh` if easier than the browser form. To switch users mid-session, clear cookies then log in again. Check the dev mailbox at `http://127.0.0.1:59302/dev/mailbox` for transfer-confirmation and completion emails.

## Seeds

`mix run priv/repo/qa_seeds.exs` (idempotent) gives the two users above plus "QA Test Account" (qa@example.com owner, qa-member@example.com read_only). If testing criterion 905 (notify ALL users, not just both transfer parties), add a disposable third member to "QA Test Account" first — e.g. register a fresh email, log in as qa@example.com, and invite it at `/app/accounts/invitations` with any access level, then accept via the dev mailbox link — so there's a bystander member to check for (or skip) a notification email.

For criterion 73/904 (originator status), seed an agency-owned client account and a real `:originator` grant:

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" -e '
alias MetricFlow.{Repo, Accounts, Agencies}
user = Accounts.AccountRepository.get_account_by_slug("qa-test-account") # adjust if needed
'
```

Simpler: this story'\''s own component test fixtures (`client_account_fixture/1` + `grant_client_account_access(.., true)`) aren'\''t reachable live — instead, use qa@example.com'\''s own account if it'\''s type `:agency`, or promote "QA Test Account" to agency type via SQL and grant it origination over a second, disposable client account via `Agencies.grant_client_account_access(scope, agency_id, client_account_id, :admin, true)` called from a `mix run` one-liner (needs a real scope — build one with `MetricFlow.Users.Scope.for_user(user)`). Note account `type` is immutable after creation (cast only on insert), so this needs either a fresh agency account or a direct SQL `UPDATE accounts SET type = 'agency' WHERE ...` plus a manually inserted `agency_client_access_grants` row with `origination_status = 'originator'`.

## What To Test

- **66/894/895 — Only the owner can initiate.** Log in as `qa-member@example.com` (read_only, non-owner) and confirm `/app/accounts/settings` has no "Transfer Ownership" card at all. Log in as `qa@example.com` (owner) and confirm the card is present.
- **67/896 — Transfer to an existing member.** As owner, submit `#transfer-ownership-form` with `transfer_target=existing`, `user_id=<qa-member's id>`. Expect a success flash and the `[data-role='transfer-pending-banner']` to appear naming the target email. Confirm via `get_pending_ownership_transfer` (or just the banner) that nothing has changed yet.
- **67/897 — Transfer via invite to a new email.** As owner, submit the form again with `transfer_target=invite`, `invite_email=<fresh unique email>`. Confirm this supersedes the prior pending transfer (banner now shows the new target) and a confirmation email appears in the dev mailbox with an `/account_transfers/:token` link.
- **68/898 — Completes only after confirmation.** Before clicking the link, verify the owner's role is still `owner` and the recipient has no access yet (e.g. re-check `/app/accounts/members`, or just that the pending banner is still showing and no completion email has arrived).
- **69/899 — Wizard asks about copy + remain-admin.** Confirm both `[data-role='transfer-make-copy-checkbox']` and `[data-role='transfer-remain-admin-checkbox']` are present and independently toggleable on the form.
- **70/900 — New owner must authenticate.** Open the `/account_transfers/:token` link from a logged-out session (clear cookies first). Confirm it shows "Sign in or create an account to confirm this transfer" with Log-In/Register buttons, not an Accept button.
- **70/901 — Unverified acceptance is blocked.** Log in as a *different* user than the transfer's target (e.g. qa@example.com itself, or any user that isn't the invited email/member) and open the same token. Click Accept if shown, and confirm it's rejected with "This transfer was not sent to your account." and no role change occurs.
- **71/902 — Acceptance transfers ownership completely.** Log in as the actual invited target, open the link, click `[data-role='accept-transfer-btn']`. Confirm redirect to `/app/accounts/settings`, the flash "You are now the owner of this account.", and that this user is now shown as `owner` (Transfer Ownership + Delete Account cards visible to them).
- **72/903 — Previous owner's access reflects their selection.** Repeat a transfer twice with different `remain_admin` values (once checked, once unchecked, using a fresh target each time to avoid a consumed transfer) and confirm the demoted previous owner ends up `admin` when checked vs `account_manager` when unchecked — check via `/app/accounts/members` as the new owner.
- **73/904 — Originator status optionally transfers.** Using the agency/originator setup from Seeds, do one transfer with `transfer_originator=true` checked and confirm `/app/agency/clients` still shows "Originated" for the new owner. Then, if time allows, repeat with the checkbox **unchecked** on a fresh originator setup — if "Originated" *still* shows either way, that's worth a note: origination status lives on the agency-to-client grant (not the owning user), so the checkbox may have no real effect regardless of its state.
- **74/905 — All users notified.** With the bystander third member from Seeds in place, complete a transfer between the owner and member, and check the dev mailbox: both transfer parties should get a completion email (confirmed already by code read). Check specifically whether the bystander (uninvolved) member also receives anything — if not, note it against the criterion's literal "all users" wording even though the narrow BDD spec only checks the two parties.
- **75/906 — Logged with both parties' confirmation.** As the new owner, reload `/app/accounts/settings` and confirm `[data-role='ownership-transfer-log-entry']` is present and its text includes both the previous owner's and new owner's email plus a confirmed timestamp.

## Result Path

`.code_my_spec/qa/10/result.md`
