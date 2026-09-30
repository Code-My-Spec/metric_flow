# QA Story 3: Multi-User Account Access — Testing Brief

## Tool

web

## Auth

Log in via the browser's password form (this working copy's own instance, not main's):

```
browser_navigate("http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view("#login_form_password")
browser_fill("#login_form_password_email", "qa@example.com")
browser_fill("#user_password", "hello world!")
browser_click("#login_form_password button[name='user[remember_me]']")
browser_wait_for_url("/")
```

Owner: `qa@example.com` / `hello world!` — owner of "QA Test Account" (account id 21).
Existing member: `qa-member@example.com` / `hello world!` — read_only on the same account.

Fresh teammates needed for role-hierarchy scenarios are created live during
the session via `/users/register` (public route, no auth needed) — each new
registrant gets their own personal account, then the owner/admin invites them
into "QA Test Account" at whatever role the scenario needs. Password
minimum is 12 characters; use `"SecurePassword123!"` for these throw-away
accounts.

To switch users: `browser_delete_cookies()` then repeat the login sequence
with the new email/password.

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Known bug (do not re-file — same root cause as issue 602c92a3 from story 47's
QA pass): the script's own "Team Account" find-or-create block does
`where: a0.type == "team"`, but `Account.type` is now `Ecto.Enum<[:client, :agency]>`
— that literal comparison always raises `Ecto.QueryError`, so the script dies
before printing its credentials banner. This does **not** block testing: the
users and the QA Test Account (id 21) already exist in the DB with the
correct baseline —

- `qa@example.com` → `owner` on "QA Test Account" (id 21, type `:client`)
- `qa-member@example.com` → `read_only` on "QA Test Account" (id 21)

Verified directly against the DB before writing this brief. If a future run
shows different roles (drift from a prior session's role-change scenarios),
reset them with a direct `Repo.update!`/`Accounts.update_user_role/4` call
rather than trying to get the broken seed script's Team Account block to run.

## What To Test

### Members page (`/app/accounts/members`) — legacy inline invite, view, role change, remove

- As owner: page shows the members table (`data-role="members-list"`) with
  `qa@example.com` badged `owner` and `qa-member@example.com` badged
  `read_only`. Invite form (`#invite_member_form`) is visible. — criteria 15,
  17, 19, 531, 534
- As owner: invite form's role `<select>` includes owner/admin/account_manager/read_only.
  — criteria 17, 18
- Register two fresh users (`alex+n@example.com`, `bob+n@example.com`).
  As owner, invite Alex as `admin` and Bob as `admin` via the Members
  invite form. Confirm both appear with the `admin` badge. — criteria 17, 20
- Log out, log in as Alex (admin). Visit `/app/accounts/members`: confirm
  the invite form's role select does **not** offer `owner`, and confirm
  whether it offers `admin` (spex `criterion_532` documents that it currently
  does **not** — see "Known contradiction" below). — criteria 18, 532
- As Alex (admin), attempt to change Bob's (the other admin's) role via the
  hidden `[data-role='change-role'][data-user-email='bob...']` control
  (`browser_evaluate` click, since it's `sr-only`). Confirm the row still
  shows `admin` for Bob afterward and an authorization-error flash appears
  (this is the behavior criterion 536 asks for, fixed by commit `260114a`
  — verify it live rather than trust the changelog). — criterion 536
- As Alex (admin), remove a third fresh read-only teammate via
  `[data-role='remove-member']`. Confirm they disappear from the list.
  — criteria 21, 537
- As owner (only owner on the account): confirm no `remove-member` or
  `change-role` control renders for the owner's own row. — criteria 20, 21,
  538
- Read-only member (`qa-member@example.com`): confirm no invite form and no
  `change-role`/`remove-member` controls anywhere on the page. — criterion 18

### Invitations page (`/app/accounts/invitations`) — real email-invite flow

- As owner: page loads, `#invite_member_form` present, role select offers
  Read Only / Admin / Account Manager (owner is not a selectable target role
  here — note if that surprises you, it's a second, independent role-select
  surface from the Members page). Submit an invite to a fresh, never-registered
  email at `read_only`. Confirm a success flash ("Invitation sent to ...")
  and the email appears in Pending Invitations with the right role badge.
  — criteria 15, 529
- Check the dev mailbox (`http://127.0.0.1:59302/dev/mailbox`) for the sent
  invitation email as corroborating evidence for criterion 529's "an
  invitation is sent" assertion.
- Cancel that pending invitation; confirm it disappears from the list.
- As Alex (admin), visit `/app/accounts/invitations`. The role select here
  is unconditional (Read Only / Admin / Account Manager for every caller,
  unlike the Members page) — try submitting an invite with role `admin`.
  Per `Accounts.Authorization.target_role_allowed?/2`, this should be
  rejected with an authorization flash even though the option was offered.
  This is a real UX inconsistency versus the Members page (which hides the
  option instead of offering-then-rejecting it) — file it if confirmed.
  — criterion 532 (see "Known contradiction" below)
- Invite the account-manager-role teammate created below, log in as them,
  and confirm visiting `/app/accounts/invitations` **redirects** to
  `/app/accounts/members` with a "You do not have permission to invite
  members" flash (matches `criterion_533`'s spex, which hits this exact
  route). — criterion 533

### Distinct credentials & data isolation

- Confirm Alex and Bob (and the owner) each log in only with their own
  email+password; a wrong password for one does not work for another.
  — criteria 16, 530
- Register a completely unrelated fresh user (their own new personal
  account, never invited anywhere). Confirm their `/app/accounts` and
  `/app/accounts/members` never mention `qa@example.com` or the QA Test
  Account's other members. — criteria 22, 539, 540

### Known contradiction to flag, not re-adjudicate

Criterion 18 ("only admins can add admins") and criterion 532 ("Admin can
invite another admin") both assume an admin can grant admin access.
`MetricFlow.Accounts.Authorization.target_role_allowed?/2` and both
invite-role selects deliberately block this — only an owner may grant admin.
`criterion_532_admin_can_invite_another_admin_spex.exs` documents this gap
in a passing-test comment rather than failing on it. File this as a single
docs-scope issue (if not already filed for this story) rather than treating
either surface's rejection of an admin-inviting-admin attempt as a bug.

## Result Path

.code_my_spec/qa/3/result.md
