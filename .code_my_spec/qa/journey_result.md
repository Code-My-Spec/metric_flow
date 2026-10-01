# QA Journey Result

## Status

pass

All 5 journeys from the plan were walked live against the running app
(`http://localhost:4070`, this worktree's dev server) and passed. Each is
now codified as a `Phoenix.LiveViewTest` module under `test/journeys/`
(see Phase 3 notes below) — the prior attempt at this phase had pivoted to
unrelated BDD-spec fixes without actually executing any journey; this run
replaces that result.

## Journey Results

### Journey 1: New User Registration to First Dashboard

**Status:** pass

Registered a fresh user, confirmed via the real magic-link email in the dev
mailbox, landed on `/onboarding`. Dashboards list showed the canned
dashboards; opening one showed the onboarding prompt ("Connect Your
Platforms") since the new user has no integrations. Account page showed the
new account with owner role. Settings page rendered email/password forms at
the real route `/app/users/settings` (the plan said `/users/settings` —
corrected). Logout redirected to `/users/log-in`; a guarded page after
logout redirected there too.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey1_*.png`

### Journey 2: Account Administration and Team Management

**Status:** pass

As owner: members list rendered with roles, invitation sent and shown in
the pending list, then cancelled and removed. Account settings edited
successfully. As the non-owner member: account visible in the switcher, but
no ownership-transfer or danger-zone controls on the settings page.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey2_*.png`

### Journey 3: Integration Dashboard and Data Sync

**Status:** pass

Connect page showed Connected status for the account's integrations;
integrations list showed real sync status, error states, and Sync Now /
Disconnect controls. Sync history page rendered real entries. Dashboard
with real metric data rendered a Vega-Lite chart, not the onboarding
prompt.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey3_*.png`

### Journey 4: Correlation Analysis and AI Insights

**Status:** pass

Goal metric selection saved and queued a correlation job; correlations page
rendered with Raw/Smart mode toggle. AI Insights, AI Chat, and the report
generator pages all rendered correctly. This journey requires an active
subscription (`RequireSubscriptionHook`) — the QA Test Account had none at
run time (it had been removed since an earlier session's test), so one was
inserted directly and removed again afterward; this is now the deliberate
setup every subsequent run of this journey needs, not a plan gap, since the
real paywall behavior (story 45) is correct and expected.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey4_*.png`

### Journey 5: Agency White-Label and Multi-Client Access

**Status:** pass

Accounts page listed multiple accounts with distinct roles (owner, admin,
account_manager, read_only). Switching to a read_only account correctly
restricted the members page. Switching back to an owned account restored
full access. Note: which account is "active" by default is whichever
account membership has the most recent `updated_at`, with no deterministic
tiebreak when two memberships are equally fresh — real user behavior is
unaffected since a real user always explicitly switches, but the Phase 3
test accounts for this by not assuming a starting account.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey5_*.png`

## Issues

None newly filed against the application — this run exercised already-
shipped, previously-QA'd surfaces and found no new application defects.
Two stale facts in the plan were corrected in place (see
`journey_plan.md`'s "Corrections" section): the settings route and the
canned dashboard names.

## Phase 3 note

Per John's decision (answer to question `5df24200`), journeys are codified
as `Phoenix.LiveViewTest` modules under `test/journeys/`, not Wallaby —
consistent with the project's e2e testing ADR, which does not use Wallaby.
All 5 files exist, each with one end-to-end test covering its journey's
steps, and `mix test test/journeys/` passes (5/5).
