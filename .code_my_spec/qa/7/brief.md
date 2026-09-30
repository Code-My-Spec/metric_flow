# QA Story 7: Manage User Access Permissions — Testing Brief

## Tool

web

## Auth

Log in via the browser's password form (this working copy's own instance):

```
browser_navigate("http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view("#login_form_password")
browser_fill("#password_email", "qa@example.com")
browser_fill("#user_password", "hello world!")
browser_click("#login_form_password button[name='user[remember_me]']")
```

Owner: `qa@example.com` / `hello world!` — owner of "QA Test Account" (account id 21).

From this story's own prior QA pass on story 3 (same working copy, same
Members/Settings implementation), the account already has these members:

- `qa-member@example.com` / `hello world!` — read_only
- `qa3-alex@example.com` / `SecurePassword123!` — admin
- `qa3-bob@example.com` / `SecurePassword123!` — admin
- `qa3-dana@example.com` / `SecurePassword123!` — account_manager

Do not re-invite these — they already satisfy "multiple access levels
visible" for criteria 44/45/552/553 without spending a fresh invite.

## Seeds

No fresh seeding needed — reuses the account/members left over from this
working copy's story 3 QA pass. If starting cold, run:

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Known bug (do not re-file, already tracked as issue ea943c9c and 602c92a3):
the script's "Team Account" find-or-create block crashes on a stale `:team`
enum comparison. Ignore the crash — the users/account/roles already exist.

Also known (issue ea943c9c): `mix run` from this working copy's shell reads
a *different* database than the one the live server at 59302 actually
serves. Do not trust direct DB queries here — verify everything through the
browser and `/dev/mailbox` instead.

## What To Test

### Members list (`/app/accounts/members`) — criteria 44, 45, 552, 553

- As owner: page shows Members heading, a `[data-role='member-row']` per
  member, owner's own email, and (from the leftover story-3 state) at least
  four distinct role badges: owner, admin, account_manager, read_only.
- Each row shows a `Mon DD, YYYY`-formatted Joined date.
- Unauthenticated request to `/app/accounts/members` redirects to
  `/users/log-in`.

### Upgrade / downgrade access — criteria 46, 49, 554, 555, 558

- As owner, use the real `<select name="role">` + "Change" button (not the
  hidden `sr-only` button — see known issue 07efe806 from story 3, still
  applies here since it's the same component) to upgrade
  `qa-member@example.com` (currently read_only) to `account_manager`.
  Expect "Role updated" flash and the new badge.
- Downgrade `qa3-dana@example.com` (account_manager) back to `read_only`
  the same way. Expect "Role updated" and the new badge.
- Permission-change logging (criterion 49/558) can't be observed from the
  browser — confirmed by reading `members.ex`: both `change_role` and
  `remove_member` handlers call `Logger.info("permission_change: ... by=... at=...")`
  before updating assigns, matching the criteria's timestamp+actor shape.
  Note this as verified-by-code-reading, not by live observation.

### Revoke access — criteria 47, 48, 557, 50, 559

- Register a brand-new throwaway user (e.g. `qa7-temp@example.com`,
  `SecurePassword123!`), invite them to QA Test Account as `read_only` via
  the Members page, confirm they appear.
- Log in as that user in a second session, confirm `/app/accounts` shows
  "QA Test Account".
- As owner, remove that user via `[data-role='remove-member']`. Expect
  "Member removed" and them disappearing from the list.
- Re-check the removed user's session: `/app/accounts` (and
  `/app/accounts/members`) must no longer show "QA Test Account" or the
  owner's email — access revoked immediately, no re-login needed.
- Confirm no `[data-role='remove-member']` control renders for the owner's
  own row (sole owner protection, criteria 50/559).

### Agency access grant/revoke — criteria 552, 556

- Register a fresh agency-type account (e.g. `qa7-agency@example.com`,
  account_name "QA7 Test Agency", account_type `agency`). Note its slug
  (derived from the account name).
- As owner, go to `/app/accounts/settings`, use `#grant-agency-access-form`
  to grant that agency `read_only` access by slug. Expect a success flash
  and "QA7 Test Agency" to appear in the agency access list.
- Use `[data-role='revoke-agency-access']` to revoke it. Expect it to
  disappear from the list.

### Ownership transfer — criterion 50

- As owner, on `/app/accounts/settings`, the `[data-role='transfer-ownership']`
  form lists non-owner members. Transfer ownership to `qa3-alex@example.com`.
  Expect "Ownership transferred successfully", and the current session (still
  qa@example.com) should now show as admin, not owner.
- **Restore the baseline immediately afterward**: log in as
  `qa3-alex@example.com` (now owner) and transfer ownership back to
  `qa@example.com`, so the next QA session's assumed baseline (qa@ = owner)
  still holds. State in the result which order this ran in.

## Result Path

.code_my_spec/qa/7/result.md
