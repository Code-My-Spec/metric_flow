# Qa Story Brief

Story 8: Agency Views and Manages Client Accounts

## Tool

web

## Auth

Use `run_browser_script` with the standard `browser_*` tools.

Owner of "QA Test Account" (the client account being granted): `qa@example.com` / `hello world!`.

Agency owner (reused from story 4's QA pass, still live): `qa4owner20260930@example.com` / `SecurePassword123!`, owns a team account of type `agency`.

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "<email>" })
browser_fill({ selector = "#user_password", text = "<password>" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
```

App base URL: `http://127.0.0.1:59302` (re-derive via `ps`/`lsof` for this worktree's `mix phx.server` if this has changed by the time testing starts).

## Seeds

No new base seeds needed. Reuses the agency account created during story 4's QA pass this session (`qa4owner20260930@example.com`, agency-type, slug is whatever `create_team_account` derived from "QA4 Agency Owner" -- confirm the actual slug from that account's own `/app/accounts/settings` — Slug field — before using it in the grant form).

**Grant setup (consumable, do once):** As `qa@example.com`, go to `/app/accounts/settings` → Agency Access section → grant the qa4owner agency slug access at `read_only`. This grant is the one live scenario used below; change its access level in place (via Revoke + re-grant, since there's no in-place level-change UI visible in the source) as scenarios progress through read_only → account_manager → admin. Note in the attempt which level was active for which scenario.

## What To Test

- **51/596: Agency sees all accessible client accounts** — As the agency owner, `/app/accounts` lists "QA Test Account" alongside the agency's own account.
- **52/597: Client listing shows access level and origination status** — The QA Test Account card shows an `.badge-accent` access-level badge (matching whatever was granted) and an `.badge-info` origination badge ("Invited", since the agency didn't create this client).
- **53/598: Agency switches between client accounts** — Click `[data-role="switch-account"]` on the QA Test Account card; confirm it becomes `data-active="true"` and its button now reads "(Active)" / is disabled, while the agency's own card flips to inactive.
- **54/599: Navigation clearly displays current client context** — After switching, confirm the top-level nav/sidebar account name updates to "QA Test Account".
- **55/600/601: Read-only agency access** — With the grant at `read_only`, switched into QA Test Account: confirm reports/dashboards are viewable, and that an integration-modifying action (e.g. Edit Accounts on an integration, or the auto-enrollment/white-label forms) is not available or is rejected.
- **56/602/603: Account manager access** — Re-grant at `account_manager`: confirm integrations can now be modified (e.g. Sync Now or Edit Accounts works), but Members/Settings-level actions (delete account, manage users) remain unavailable.
- **57/604/605: Admin access** — Re-grant at `admin`: confirm broader access (members visible/manageable) but the account cannot be deleted by the agency user.
- **58/606/607: User visibility by access level** — At `read_only`/`account_manager`, confirm `/app/accounts/members` for QA Test Account does not reveal the full member list to the agency user (or is inaccessible). At `admin`, confirm it does.
- **59/608: Originator badge** — Not exercised live in this pass (would require the agency to have *created* the client account via a different flow than a simple access grant); verify via the passing `criterion_59`/`criterion_608` BDD spex instead and say so explicitly in the observation.

## Result Path

.code_my_spec/qa/8/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings — there is no `result.md` file; the path above is where screenshot evidence is saved. This story's permission matrix (4 access levels × multiple gated actions) is large; live coverage focuses on one representative action per level rather than exhaustively re-testing every criterion's own page, with the remainder backed by the passing story 8 BDD spex suite where a live repro isn't practical in the time available.

## Results

- 51/596, 52/597: pass. `/app/accounts` as the agency owner lists "QA Test Account" alongside the agency's own account, with correct access-level (`.badge-accent`) and origination (`.badge-info` "Invited") badges.
- 53/598, 54/599: pass. Clicking `[data-role="switch-account"]` flips `data-active`/button state correctly on both cards, and the top nav/sidebar updates to "QA Test Account" with a "Switched to QA Test Account" flash, confirmed live.
- **Important correction made mid-pass:** initially misread the permission model from `integration_live/index.ex` and `account_live/members.ex` alone — both compute `can_sync`/`can_modify`/`can_manage` from `Accounts.get_user_role/3`, which only queries `AccountMember`, and concluded an agency grant (which creates an `Agencies.AgencyAccessGrant`, not an `AccountMember`) could never satisfy those checks. This is wrong: `MetricFlow.Agencies.grant_agency_access_from_client/4` calls `propagate_client_access_to_team/3` (lib/metric_flow/agencies.ex:570), which inserts a real `AccountMember` row on the client account for every agency team member with `role = access_level`, and revoke deletes it. So `get_user_role/3` correctly reflects the current grant level after all. Filed issue 7a8a0639 on this premise, then dismissed it once the live re-grant test (read_only → admin) proved it wrong — see the dismissal reason on that issue for the full trace.
- 55/600/601: partial. At `read_only`, Sync Now and Disconnect are correctly absent/blocked (both gated by `can_sync`/`can_modify`, both false for a `:read_only` member). Reports page loads fine (viewing is ungated). However "Edit Accounts" — the brief's own example of a modifying action — is **not** gated at all, on either the link or the destination LiveView (`account_edit.ex` has no role check whatsoever). Filed as issue b3a6e490-6386-45bb-afd4-482aa916812e (medium), not live-clicked end-to-end since QA Test Account has no connected integrations to attach an "Edit Accounts" link to, but confirmed via full code read of both files.
- 56/602/603: pass. Re-granted at `account_manager`; `/app/accounts` badge updates to "Account Manager", `get_user_role` now returns `:account_manager`, unlocking `can_modify`-gated actions. `/app/accounts/members` correctly still hides the full members-list card (`can_manage?` requires `:owner`/`:admin`).
- 57/604/605, 58/606/607: pass. Re-granted at `admin`; `/app/accounts/members` now shows the full members table (agency owner appears as a member with role "admin", Change/Remove controls visible) confirming `can_manage` unlocks correctly. `/app/accounts/settings` shows no "Delete" affordance for the agency-derived admin (account deletion stays unavailable).
- 59/608 (Originator badge): deferred to the passing story 8 BDD spex suite, not exercised live — would require the agency to have *originated* the client account via a different flow than a simple access grant, which this pass's fixtures don't set up.

## Retest (after coder fix for b3a6e490)

The coder's fix added a `can_modify` check to `IntegrationLive.AccountEdit` (router path `/integrations/:provider/accounts/edit`, `:edit` action) and gated the Edit Accounts link's own `can_modify` flag. That fix is correct for its own module, but it targets the wrong LiveView: the actual "Edit Accounts" button (`lib/metric_flow_web/live/integration_live/index.ex:208-218`) navigates to `~p"/app/integrations/connect/#{provider}/accounts"`, which the router maps to `IntegrationLive.Connect`'s `:accounts` action -- a completely different, unrelated module with no authorization check anywhere (`handle_accounts_params/2` and `handle_event("save_account_selection", ...)` both run unconditionally). Confirmed live: navigating there as a read_only agency user shows Connect's own unrelated "connect first" flash instead of the AccountEdit fix's "not authorized" redirect, proving the role check is never reached on the real path. Filed as issue da260f29-7fe8-41c0-9b6d-e28a62148087 (high) and resubmitted as `partial`. `submit_qa_result` accepted the issue-linked submission cleanly this time (attempt c8856eb3), unlike the rollback seen earlier in this session (see framework issue 89845d87) -- that bug may have been transient.

## submit_qa_result tool bug hit during this pass

Discovered `submit_qa_result` rolls back with an opaque error whenever `issue_ids` is non-empty on any call after the first successful one for a given `task_id` (independent of which issue, top-level status, or scenario count/status) — filed as framework issue 89845d87-9b3f-4fe8-9094-5806032e634f. Diagnosing this accidentally left a trivial no-issue `pass` attempt (1c01b1ec) as canonical, incorrectly satisfying `qa_complete`; invalidated it via `invalidate_qa_attempt` so the real result (attempt 6937f3e2, status `partial`, issue b3a6e490 linked) is the valid standing record. This file is the source of truth for the full scenario-by-scenario detail, since the `scenarios` array itself could only be populated once per task for the same reason.
