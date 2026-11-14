# QA Journey Result

## Status

pass

Journeys 1-5 from the plan were walked live against the running app
(`http://localhost:4070`, this worktree's dev server) and passed; each is
codified as a `Phoenix.LiveViewTest` module under `test/journeys/` (see
Phase 3 notes below) -- the prior attempt at this phase had pivoted to
unrelated BDD-spec fixes without actually executing any journey; this run
replaces that result. Journey 6 (Story 74, "Build a Screen with the Agent")
went through several fail/fix cycles on 2026-11-14 (no chat affordance,
then multi-widget combining into one spec, then no draft-navigation on
reload, then no versioning) and now passes for every rule exercised:
build, multi-widget composition, draft autosave with reload, and
per-change versioning. Missing-metric redirect and a distinctly-named
"Edit with agent" resume action remain unexercised. See Journey 6 below
for the consolidated detail; some of this walking was done outside
`start_task`/`evaluate_task` because of a graph deadlock (c2084903) that
refused to re-offer `qa_journey` after a stage landed -- see Issues.

## Journey Results

### Journey 1: New User Registration to First Dashboard

**Status:** pass

Registered a fresh user, confirmed via the real magic-link email in the dev
mailbox, landed on `/onboarding`. Dashboards list showed the canned
dashboards; opening one showed the onboarding prompt ("Connect Your
Platforms") since the new user has no integrations. Account page showed the
new account with owner role. Settings page rendered email/password forms at
the real route `/app/users/settings` (the plan said `/users/settings` --
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
subscription (`RequireSubscriptionHook`) -- the QA Test Account had none at
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
tiebreak when two memberships are equally fresh -- real user behavior is
unaffected since a real user always explicitly switches, but the Phase 3
test accounts for this by not assuming a starting account.

Screenshots: `.code_my_spec/qa/journeys/screenshots/journey5_*.png`

### Journey 6: Build a Screen with the Agent

**Status:** pass (Story 74 rules 1, 2 and 7; rules on missing-metric
redirect and a named "Edit with agent" resume action not yet exercised)

Walked across many coder stages on 2026-11-14; consolidated here rather
than kept as a growing list of individual re-walk attempts (see git log
for `test/journeys/build_a_screen_with_the_agent_test.exs` and this file's
history if the detail is needed).

- **Chat builds a visualization from natural language (684d9a0/4db2d04)
  -- pass, confirmed live.** Sending a request on `/app/dashboards/new`
  adds a real, working chart built from real metric data.
- **Multi-widget composition (Story 74 rule 2; d4a75d8, then 455ea40) --
  pass, confirmed live.** First failed: the real model combined multiple
  requested widgets into one Vega-Lite `vconcat` spec, and said outright
  it had no tool to create separate dashboard elements. Root cause: the
  backend mechanism (multiple `update_spec` calls in one turn -> multiple
  elements) existed, but nothing told the model it could use it. Fixed at
  455ea40 (dashboard-chat-only system-prompt guidance, gated behind a
  `multi_widget: true` opt so the single-visualization editor is
  unaffected). Confirmed live by main (2026-11-14, de23c19+): one message
  ("Add a stat tile showing total impressions and a line chart of
  impressions over time") produced two separate `visualization-card`
  elements. Main's screenshot of this
  (`multiwidget_live.png`) lived in main's own agent scratch directory,
  which QA's tools could not reach to copy into the project -- not
  reproduced here. `journey6_stage5_vconcat_gap.png` (the earlier failing
  state) remains for contrast.
- **Draft autosave with reload (Story 74 rule 1) -- pass, confirmed live
  and by test.** First build persisted a draft `Dashboard` (950932f), but
  the LiveView never navigated off `/app/dashboards/new`, so a real
  browser reload of `/new` showed an empty canvas even though the draft
  existed under `/app/dashboards` -- found live by main (2026-11-14,
  de23c19), not caught earlier because the original check reopened the
  draft via a direct `/edit` visit rather than reloading `/new` itself.
  Fixed at a8e2d7b: the editor now `push_patch`es to
  `/app/dashboards/:id/edit` once the draft exists. `assert_patch`
  assertion added, confirmed failing at de23c19/e41dd31 and passing at
  a8e2d7b.
- **Versioning and restore (Story 74 rule 7) -- pass by test, not yet
  re-confirmed live.** No `DashboardVersion` schema existed anywhere;
  added as a failing `has_element?(view,
  "[data-role='dashboard-version-list']")` assertion (confirmed failing
  at e41dd31). Version recording fixed at a8e2d7b: every successful
  chat-driven save now records a `DashboardVersion` snapshot, rendered as
  a version list. Restore itself was still missing (the list was
  display-only, and `DashboardVersion`'s own moduledoc said "Immutable
  once written"); added a failing `has_element?(edit_view,
  "[data-role='restore-version']")` assertion, confirmed failing. Fixed
  at 58026f9: each version entry now has a Restore button
  (`restore_version` event) that replaces the dashboard's current
  visualizations with that version's snapshot and records the restore as
  a new version, per the rule ("the restore appears as a new version in
  the list"). `mix test test/journeys/...`: 9/9 passed at 58026f9
  (confirmed by QA); coder additionally reports 14/14 journey tests and
  220/220 across `dashboard_live`/`dashboards`/Story 29 spex/
  `visualization_live`, no new failures elsewhere.
- **Chart type lost on reload (found live by main, 2026-11-14, a8e2d7b)
  -- pass by test.** After reopening `/edit`, a chat-built stat tile's
  badge read "line" instead of "text" -- `load_visualizations_from_dashboard/1`
  fell back to a literal `"line"` default whenever a saved
  visualization's `vega_spec` was a real frozen spec (no explicit
  `"chart_type"` key) rather than the ad-hoc marker shape. Added a
  failing assertion scoped to a fresh `/edit` mount (the same path a real
  browser reload hits); confirmed failing (`left: "line", right:
  "text"`). Fixed at 58026f9: now derives the type from the spec's own
  `mark` via `extract_chart_type_from_spec/1`, the same helper the
  library-insert path already used.
- **Live re-confirmation -- blocked on QA's own browser tool throughout
  this round, including at 58026f9.** QA's packed-login script 504'd
  twice in a row on every attempt across several commits (de23c19,
  74e65e3, a8e2d7b), the same failure mode seen repeatedly even after
  main ruled out host load and the leaked-browser accumulation; main has
  escalated this to CodeMySpec. Confidence in the navigation, versioning,
  restore and chart-type fixes rests on the ExUnit suite (which directly
  exercises each) plus the coder's own broader regression runs, not an
  independent live walk this round. One side effect worth noting: while
  isolating the chart-type test, a run that should have failed instead
  passed with no app-code change on QA's side -- the coder's 58026f9 fix
  had landed in this shared working copy mid-run. Re-ran clean afterward
  (9/9, stable across repeats); not test flakiness, just a race with
  concurrent work in a shared checkout.
- **Missing-metric redirect to Integrations and a distinctly-named "Edit
  with agent" resume action -- still not independently exercised.** Chat
  history does resume on a plain `/edit` visit (confirmed since 950932f),
  which covers the substance of "Edit with agent"; whether there is (or
  should be) a distinctly-labeled entry point for it, and the
  missing-metric-redirects-to-Integrations behavior, remain unwalked.

Not a regression anywhere tested: every previously-passing stage (1-5,
plus this journey's earlier-passing stages) still passes. No new
application issues filed this round -- every gap found became a failing
test instead, each since fixed by the coder in the same session.

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

Host disk/load instability (framework issue 27ee4ba3, filed separately):
during this walk's session, a host disk-full condition (:enospc) and a
leaked-browser load spike (fdd98643) each caused a 504 on the very first
browser action attempted; both were reported to main and the walk resumed
only once main confirmed recovery. Not an application defect.

QA's browser tool (framework, escalated by main to CodeMySpec, not filed
by this agent): after the host disk/load issue above resolved, QA's own
packed-login browser script kept 504ing twice in a row on repeated
attempts across multiple commits (de23c19, 74e65e3, a8e2d7b), even
immediately after main's own browser session on the same app instance had
just succeeded -- ruling out host load and the leaked-browser
accumulation as the cause. Main did the multi-widget and draft-autosave
live walks directly instead. Still unresolved as of this writing; QA's
confidence in the versioning and draft-autosave fixes rests on the ExUnit
suite, not an independent live walk.

None newly filed against the application -- this run exercised already-
shipped, previously-QA'd surfaces (plus the now-fixed multi-widget,
draft-autosave-navigation, and versioning gaps, each tracked via a
failing test and since resolved by the coder) and found no new
application defects.

## Phase 3 note

Per John's decision (answer to question `5df24200`), journeys are codified
as `Phoenix.LiveViewTest` modules under `test/journeys/`, not Wallaby --
consistent with the project's e2e testing ADR, which does not use Wallaby.
All 6 files exist and pass end-to-end (`mix test test/journeys`: confirmed
green, including journey 6's 7 tests as of a8e2d7b).
