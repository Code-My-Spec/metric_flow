# Qa Story Brief

Story 6: Agency or User Accepts Client Invitation

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools. Log in as the seeded QA owner to send invitations from "QA Test Account":

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

Invitations are sent from `/app/accounts/invitations` via `#invite_member_form` (email + role select), matching the pattern already used in story 3's QA pass this session. The dev mailbox at `/dev/mailbox` shows sent emails; each invitation email contains a link matching `/invitations/<token>`.

App base URL: `http://127.0.0.1:59302` — this worktree's own dev server, confirmed live throughout this session. Re-derive via `lsof -nP -iTCP -sTCP:LISTEN | grep beam` / `ps` if it has changed.

## Seeds

Seeds already in place: `qa@example.com` (owner of "QA Test Account") can send invitations. `qa-member@example.com` is already a read_only member and should NOT be used as an invitee target (already a member — would only exercise the already-member path, not a fresh acceptance).

**Invitation tokens and invitee emails are single-use, consumable inputs.** Each scenario below sends a fresh invitation to a fresh, never-before-invited email address (timestamp-suffixed, e.g. `qa6invitee-<n>@example.com`), since a token is invalidated the moment it's used (accepted or declined) and an email that's already an account member hits the `already_member` path instead of a clean first-time accept. Record which literal email/token was used for which scenario in the attempt's observations, in case a retest needs to know what's already spent.

For the agency-team scenario (837), reuse one of the fresh agency owners created earlier this session on this same checkout: `qa30owner20260930@example.com` / `SecurePassword123!` (owner of "QA30 Agency Owner", agency-type, still live from story 30's pass) — invite that email address to "QA Test Account" and log in as it to accept.

**Critical environment note carried over from stories 13/15/8/18/33/30/31 this session:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`, not the default `metric_flow_dev`. Any `mix run -e` shell must `export DATABASE_NAME=metric_flow_dev_wc_bd0baac8` first. Backdating an invitation's `expires_at` for the expired-invitation scenario requires a direct SQL update against this database (there's no UI path to expire one, per the story's own BDD spex comment) -- use a fresh, freshly-sent invitation's `token_hash` row (matched by inviting a fresh email, then updating `invitations` by that email/status='pending') rather than guessing an id.

## What To Test

- **37/831: invitation link opens the acceptance page** — As qa@example.com, invite a fresh email. While still logged in as the owner (simulating "already logged in" clicking their own sent link is not meaningful; instead open the link in a fresh session logged in as a *different*, already-registered user) OR simply confirm the page loads correctly showing the inviter's email, account name, and role for a logged-in session. Confirm `[data-role="accept-btn"]` and `[data-role="decline-btn"]` are present.
- **38/832: if not logged in, user is prompted to log in or register** — `browser_delete_cookies` then navigate directly to the invitation link with no session. Confirm `[data-role="log-in-btn"]` ("Log In to Accept") and `[data-role="register-btn"]` ("Create an Account") are shown instead of accept/decline. Click "Log In to Accept" and confirm it navigates to `/users/log-in?return_to=...` with the invitation path encoded.
- **39/833: upon acceptance, user account is granted the specified access level** — Register a brand-new user with a fresh email (no prior relationship to "QA Test Account"), then have that new user open the invitation link and click "Accept Invitation". Confirm a success flash ("You now have access to QA Test Account") and redirect to `/app/accounts`.
- **40/834: user sees client account added to their account switcher or list** — Immediately after accepting (previous scenario), confirm `/app/accounts` lists "QA Test Account" for this new user, with the role that was specified in the invitation (e.g. read_only).
- **41/835: expired invitations show a clear error message** — Send a fresh invitation, then backdate its `expires_at` in the DB to the past (see Setup Notes). Open the invitation link fresh (logged out or as a fresh registrant) and confirm a flash reading "This invitation has expired." and a redirect to `/`.
- **42/836: already-accepted invitations cannot be reused** — Using the accepted invitation from criterion 39/833's scenario, revisit the exact same `/invitations/<token>` URL again (same accepting user, still logged in). Confirm a flash reading "This invitation is no longer valid."/"invalid or has already been used" and a redirect to `/` — not a second successful grant.
- **43/837: if invitee is part of an agency, entire agency team gets access based on agency team structure** — Invite `qa30owner20260930@example.com` (agency owner, see Seeds) to "QA Test Account" at `account_manager`. Log in as that agency owner, accept the invitation, confirm they personally gain access (`/app/accounts` shows "QA Test Account"). Then check whether the agency's *other* team members (if any exist on "QA30 Agency Owner") also gained access to "QA Test Account" — read `MetricFlow.Invitations.accept_invitation/2`'s source first: it inserts exactly one `AccountMember` row for the accepting user and has no reference to `Agencies`/`propagate_client_access_to_team` at all (that helper exists only on the separate `Agencies.grant_client_account_access/4` code path, confirmed via grep). If "QA30 Agency Owner" has no other team members to test against, this is still a code-review-backed finding worth filing rather than skipping, since the mechanism the criterion describes appears entirely absent from this flow.

## Result Path

.code_my_spec/qa/6/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved.

To backdate a specific invitation's expiry without guessing its id, match on the invitee email and pending status:

```bash
DATABASE_NAME=metric_flow_dev_wc_bd0baac8 PGPASSWORD=postgres psql -h localhost -U postgres -d metric_flow_dev_wc_bd0baac8 -c "update invitations set expires_at = now() - interval '1 hour' where email = '<fresh-invitee-email>' and status = 'pending';"
```

## Results

Emails/tokens consumed this pass: `qa6invitee1-20260930@example.com` (accepted, then re-visited to confirm already-used rejection), `qa6expired-20260930@example.com` (backdated, never accepted), `qa30owner20260930@example.com` (accepted at account_manager -- their agency access grant to "QA Test Account" from earlier stories is unrelated and untouched), `qa6teammate-20260930@example.com` (fresh, added to the agency as a synthetic AccountMember fixture for the propagation check, then removed afterward -- do not reuse this email as still-a-member of anything).

- 37/831, 38/832: pass. `/invitations/<token>` loads with inviter email, account name, and role shown. Logged out, it correctly shows Log In to Accept / Create an Account instead of Accept/Decline, and Log In to Accept correctly redirects to `/users/log-in?return_to=/invitations/<token>`.
- 39/833: pass. A newly registered user accepting a fresh invitation gets the flash "You now have access to QA Test Account." and redirects to `/app/accounts`.
- 40/834: pass. `/app/accounts` immediately shows "QA Test Account" for the new user with the exact role specified in the invitation (read_only).
- 41/835: pass. A backdated (expired) invitation shows "This invitation has expired." when opened.
- 42/836: pass. Revisiting an already-accepted invitation's link shows "This invitation link is invalid or has already been used." -- no second grant, confirmed by the flash text alone (no DB re-check needed since the message itself proves the `do_accept`/`already_member` guard fired).
- 43/837: **fail**. Confirmed live: added a fresh user as a member of an agency-type account, then had that agency's owner accept a fresh client invitation. The owner correctly gained the specified role (account_manager) on the client account, but the agency's other team member gained nothing at all -- `account_members` for "QA Test Account" has no row for them. `Invitations.accept_invitation/2` has no agency-propagation logic anywhere (confirmed via source read), unlike the separate `Agencies.grant_client_account_access/4` path which does propagate to the whole team (verified working in story 8's pass). Filed high issue 90a57ccf.

## Retest 2026-10-01

Fix for issue `90a57ccf` (commit 32b4af5, `Agencies.propagate_client_access_via_user_agencies/3`) confirmed both at the unit level and live:

- `mix test test/metric_flow/invitations_test.exs` -- 43/43 passed, including the new dedicated regression test "propagates access to the rest of the invitee's agency team".
- Live repro with fresh fixtures (not reused from the prior attempt, since the prior attempt's emails/accounts are spent): agency account 69 ("QA6 Retest Agency", invitee user 64 as admin, teammate user 65 as read_only) and client account 70 ("QA6 Retest Client", owned by qa@example.com). Sent a fresh invitation to the invitee at `account_manager`, accepted it as the invitee via the browser, then confirmed via DB: both user 64 and user 65 hold `account_manager` on account 70. The invitee's own account switcher also correctly shows the new client account.

43/837 now: **pass**. All other criteria (37-42, 831-836) were already verified passing in the prior attempt and are unaffected by this fix. Submitting as pass.
