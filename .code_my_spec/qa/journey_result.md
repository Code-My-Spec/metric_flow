# QA Journey Result

## Status

mixed

Journeys 1-5 from the plan were walked live against the running app
(`http://localhost:4070`, this worktree's dev server) and passed; each is
codified as a `Phoenix.LiveViewTest` module under `test/journeys/` (see
Phase 3 notes below) — the prior attempt at this phase had pivoted to
unrelated BDD-spec fixes without actually executing any journey; this run
replaces that result. Journey 6 (Story 74, "Build a Screen with the Agent") was added and first
walked against commit 5d7b86d7 (fail -- no chat affordance existed at all),
then re-walked outside the normal task loop against commit 4db2d04 after the
coder landed the first stage: chat now builds a single visualization from
natural language using real data (pass), but draft autosave, multi-widget
composition, missing-metric guidance, agent-chat history, and
versioning/restore remain unbuilt. The journey stays codified as a failing
test (untouched by this re-walk) rather than a passing one, since most of
Story 74's criteria still have no code to attach to. The re-walk itself was
done outside `start_task`/`evaluate_task` because of a graph deadlock
(c2084903) that refused to re-offer `qa_journey` after the first stage
landed; see Issues.

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

### Journey 6: Build a Screen with the Agent

**Status:** partial (re-walked outside the task loop; graph deadlock c2084903
tracked separately, see Issues)

**First walk (commit 5d7b86d7):** fail at step 2. `/app/dashboards/new` was
the existing manual builder only ("Start from a template or blank canvas" +
"+ Add Visualization"), with no chat affordance anywhere. Screenshot:
`.code_my_spec/qa/journeys/screenshots/journey6_new_dashboard.png`.

**Re-walk (commit 4db2d04, this copy's app at `http://127.0.0.1:53149`):**
the coder landed the first stage. Logged in as `qa@example.com` and opened
`/app/dashboards/new`:

- **Chat builds a visualization from natural language — pass.** A "Build
  with AI" panel (`[data-role='dashboard-chat-input']` /
  `[data-role='dashboard-chat-send-btn']`) is present. Sending "Show me a
  spend-over-time line chart" added a working line chart ("Spend Over
  Time", plotting `total_cost` by date) to the canvas, with the agent's
  reply explaining the metric choice and offering follow-ups. Screenshot:
  `.code_my_spec/qa/journeys/screenshots/journey6_stage2_chat_built_chart.png`.
- **Draft autosave on first build — fail / not built.** Reloading the page
  after the chart was built returned to the blank "/new" state ("Add a
  visualization to get started") with the chat history and chart gone; the
  URL never moved off `/app/dashboards/new` to a persisted dashboard id. No
  dashboard record is created until an explicit "Save Dashboard" click, so
  Story 74's "saved as a draft the first time the agent builds something,
  with no explicit save needed" rule does not hold yet.
- **Mixed widget types in one request, missing-metric redirect to
  integrations, "Edit with agent" resuming a saved dashboard's history, and
  per-change versioning with restore — not built.** Not independently
  re-tested this walk (per main's guidance, since only `dashboard_live/
  editor.ex` changed in 684d9a0); recorded as not-built rather than
  regressions, consistent with the Dashboard schema still having no
  draft/version fields.

Not a regression anywhere tested: everything that worked before still
works, and the one new capability (single-visualization chat building)
works as described. The remaining Story 74 criteria (draft persistence,
multi-widget composition, missing-metric guidance, agent-chat history,
versioning/restore) still have no code to attach to and remain open coder
work, tracked via the still-committed failing test rather than a new issue.

## Issues

Graph deadlock c2084903 (framework, tracked by main/CodeMySpec main, not
filed by this agent): after the coder landed journey 66a06609's first stage
(684d9a0, then client_utils/diagnostics fix at 4db2d04), the graph kept
reporting the story as `blocked: the walk is red; the coder fixes it` and
refused both `get_next_requirement` and a direct `start_task` claim for
`qa_journey` on this journey, apparently still reading the earlier failed
walk rather than the new green compiler/exunit runs. The Journey 6 re-walk
above was done as recorded evidence outside `start_task`/`evaluate_task` at
main's direction while that deadlock is escalated.

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
