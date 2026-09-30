# Qa Story Brief

Story 5: Client Invites Agency or Individual User Access

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

Send page: `/app/accounts/invitations` (owner of "QA Test Account"). Dev mailbox: `/dev/mailbox`.

App base URL: `http://127.0.0.1:59302` -- re-derive via `lsof`/`ps` if changed.

## Seeds

Seeds already in place. This story's live flow (send/cancel/list invitations) was already exercised in depth during story 6's QA pass this session (which tests the *acceptance* side using invitations sent from this exact page) -- criteria 29/886 (send to any email), 30/887 (7-day expiry link), 31/888 (email delivery), 32/889 (shows account name + role), and 34/891 (single-use, invalidated after acceptance/expiration) were all already confirmed live there. This pass focuses on the parts story 6 didn't need to touch: viewing/cancelling pending invitations (35/892), sending multiple invitations with different roles and seeing them listed together (36/893), and the full access-level range including `admin` (33/890).

All invitee email addresses below are fresh, timestamp-suffixed strings, consumed once tested (a re-send to the same email/still-pending invitation is a different but related scenario, not needed here).

**Critical environment note carried over from this session:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first.

## What To Test

- **33/890: client can specify access level: read-only, account manager, or admin** -- As qa@example.com (owner), open `/app/accounts/invitations` and confirm the Access Level select offers all four options (`read_only`, `account_manager`, `admin`, `owner` -- per `invite_roles(:owner)` in the source) with `read_only` selected by default. Submit an invitation at `admin` level for a fresh email and confirm it's accepted (no validation error) and appears in Pending Invitations with an "Admin" badge.
- **35/892: client can view pending invitations and cancel them before acceptance** -- Send one more fresh invitation, confirm `[data-role='pending-invitation-row']` shows its email, role badge, "Sent ... ago", and "Expires <date>". Click `[data-role='cancel-invitation']` for that row and confirm it disappears from the list with a "cancelled" flash. Then attempt to open that cancelled invitation's link (from the dev mailbox) and confirm it shows the same "invalid or has already been used" error as an already-accepted one (cancelling reuses the same accepted/declined-style invalidation).
- **36/893: client can invite multiple agencies or users with different access levels** -- Send two more fresh invitations in the same session without reloading: one at `account_manager`, one at `read_only`. Confirm both appear simultaneously in Pending Invitations, each with its own correct email and role badge, and confirm both emails were actually delivered (check `/dev/mailbox` for both).
- **Admin-role restriction (from source, not a listed criterion but worth confirming doesn't regress)** -- Log in as `qa-member@example.com` if it's ever promoted to `admin` in a fresh scenario, or simply note from `invite_roles(:admin)` in `send.ex` that admins are restricted to `read_only`/`account_manager` options only (no `admin`/`owner`) -- this matches the privilege-escalation fix already verified in story 3's QA pass this session. Not re-tested live here since story 3 already covers it; just confirm the current source still has this restriction (grep) so a regression would be caught by story 3's own suite, not silently reintroduced only on this page.

## Result Path

.code_my_spec/qa/5/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings -- there is no `result.md` file; the path above is where screenshot evidence is saved. Criteria 29/886, 30/887, 31/888, 32/889, and 34/891 are considered already covered by story 6's QA pass this session (attempt for task 5ceba28a) and are not re-exercised live in this pass; if that attempt is ever invalidated, this story's `qa_complete` should be revisited too since it relies on that evidence.

## Results

- 33/890: pass. The Access Level select on `/app/accounts/invitations` offers all four options (Read Only, Account Manager, Admin, Owner) with Read Only selected by default. Submitted an invitation at `admin` level for a fresh email; accepted with no validation error and appeared in Pending Invitations with an "Admin" badge, "Sent just now", and the correct 7-day expiry date.
- 35/892: pass. The pending row showed the email, role badge, relative sent-time, and expiry date. Clicking Cancel removed the row immediately with a "cancelled" flash, and confirmed via direct DB check the row disappeared. Opening that cancelled invitation's own link afterward correctly shows "This invitation link is invalid or has already been used." -- cancellation invalidates the token exactly like acceptance does.
- 36/893: pass. Sent two more invitations in the same session (account_manager to one address, read_only to another) without reloading; both appeared correctly in Pending Invitations on a fresh reload with their own emails and role badges, and both rows are backed by real `invitations` DB rows with the correct roles. (Two immediate post-submit visibility checks briefly returned false due to a stale-DOM/selector-mismatch artifact -- my own `data-email` attribute assumption was on the wrong element -- not a real app bug; corrected by re-querying the right selector and by a fresh page reload, both of which confirmed the rows are present.)
- Admin-role restriction: confirmed unchanged via source read (`invite_roles(:admin)` in send.ex still restricts admins to read_only/account_manager only), consistent with story 3's already-verified fix. Not re-tested live.

No issues found for this story.
