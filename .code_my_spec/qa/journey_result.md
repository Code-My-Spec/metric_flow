# QA Journey Result

## Status

mixed

Journeys 1-5 from the plan were walked live against the running app
(`http://localhost:4070`, this worktree's dev server) and passed; each is
codified as a `Phoenix.LiveViewTest` module under `test/journeys/` (see
Phase 3 notes below) -- the prior attempt at this phase had pivoted to
unrelated BDD-spec fixes without actually executing any journey; this run
replaces that result. Journey 6 (Story 74, "Build a Screen with the Agent")
went through many fail/fix cycles on 2026-11-14 (no chat affordance,
multi-widget combining into one spec, no draft-navigation on reload, no
versioning, chart type lost on reload, missing-metric redirect, "Edit
with agent" label, no widget awareness after reopening, no filter
control, no default date range) and now passes all of those plus error
handling (already built, confirmed by a new test). Still failing and
now codified: a filter control's value doesn't persist across a
reopen, the one rule left for the coder. See Journey 6 below for the
consolidated detail; some of this walking was done outside
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

**Status:** fail (rules 1, 2, 3, 4, 5, 6 and 9 pass; rule 8 -- filter
values don't persist on reopen -- fails, now codified as the coder's
next work)

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
  a8e2d7b. Confirmed live by main (2026-11-14, a8e2d7b): on
  `/app/dashboards/new`, one message produced 2 cards and the editor
  moved to `/app/dashboards/11/edit`; a reload kept both cards, both
  chat messages, and showed "Version 1 -- Nov 14, 2026 05:39" in the
  version list. Screenshot (main's agent scratch, not copied into the
  project):
  `/Users/johndavenport/.codemyspec/agent_scratch/0521fa8d-76ea-41ee-97cc-ff698c2a5fb7/reload_after_build.png`.
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
- **Missing-metric redirect to Integrations (Story 74 rule 3) -- pass.**
  Rule: "the agent says which metric is missing and points her to
  integrations... offers a link to connect a platform." With no synced
  metrics, the agent's chat reply said "No metrics are available yet.
  Connect a platform in Integrations to get started." -- prose only,
  rendered as plain escaped text
  (`<p class="whitespace-pre-wrap">{msg.content}</p>` in
  `dashboard_live/editor.ex`), not an actual link. Added a test scoped
  to the chat message itself (not the whole page, since the sidebar nav
  already links to `/app/integrations` regardless, which would make an
  unscoped assertion pass for the wrong reason -- caught and fixed
  before committing). Confirmed failing, then fixed at d7a1c40: the
  reply now carries a real link (`msg.link`), rendered via `<.link>`,
  separate from the prose. Confirmed passing.
- **"Edit with agent" entry point (Story 74 rule 4) -- pass.** Chat
  history does resume on a plain `/edit` visit (confirmed since
  950932f), so the substance of the rule already worked; the dashboards
  index only offered a generic "Edit" link
  (`data-role="edit-dashboard-:id"`), never the words "Edit with
  agent". Added a test asserting that text appears after building a
  dashboard; confirmed failing, then fixed at d7a1c40 (the link's label
  text changed to "Edit with agent"). Confirmed passing.
- **Agent's awareness of existing widgets after reopening (Story 74 rule
  4 / criterion 1062) -- pass.** The rule's point isn't just the entry
  point's label but that "the agent continues from the current
  dashboard." Confirmed live by main (2026-11-14, 58026f9): asked to
  refine a reopened dashboard, the real model said "I also don't see a
  line chart or stat tile in this conversation, so there's nothing for
  me to edit." Root cause: `dashboard_chat_context` reset to `nil` on
  every `/edit` mount, and `current_spec` was never passed to
  `VizChat.send_message` on the dashboard chat path. Added a
  capture-based test (no scripted model answer, per main's
  instruction): asserts the real prompt payload sent on a reopened
  dashboard's first message mentions an existing widget's name.
  Confirmed failing, then fixed at a5e660d (existing widgets are now
  passed to the dashboard chat). Confirmed passing. Story 74 has no
  rule about removing widgets through chat, so the test only checks the
  widget is mentioned, not that the model is told it may delete
  anything.
- **Interactive filter control exists (Story 74 rule 5 / criterion
  1063) -- pass.** Rule: "Interactive controls on a dashboard only
  re-run metric queries and change what is shown; they never write
  anywhere or call other tools." No concept of an interactive control
  dashboard element existed anywhere in `dashboard_live/editor.ex`.
  Added a test asserting a filter-control element exists; confirmed
  failing, then fixed at a5e660d (a `[data-role='filter-control']`
  date-range select, `filter_date_range` event, re-runs queries only --
  no write, no tool call, matching the rule). Confirmed passing.
- **A model error leaves the dashboard unchanged (Story 74 rule 6 /
  criterion 1064) -- pass, already satisfied.** Rule: "Dana sees a
  clear error in the chat and the dashboard stays exactly as it was ...
  and she can retry the request." Test simulates a real Claude Code CLI
  failure via `ClaudeCodeStub.error/2` (not just a page render check,
  per main's follow-up request to verify this): the chat shows
  "Error: ...", the dashboard's visualization cards -- parsed from the
  actual rendered HTML, compared before and after -- are unchanged, and
  the send button isn't left disabled. Passed without any coder change
  needed -- `finish_dashboard_chat_with_error/2` already appends a
  clear error message, resets the "generating" flag, and never touches
  `:visualizations`. Reported this honestly rather than forcing a
  failing assertion main's instruction implied: the rule was already
  built, just never previously covered by a journey test.
- **A filter's value persists on reopen (Story 74 rule 8 / criterion
  1066) -- fail, now codified correctly.** Rule: a filter control's
  value (e.g. a narrowed date range) is "saved with the dashboard" and
  still shows on reopen. First version of this test only checked that
  the filter-control element existed on the same view -- main caught
  that this passed for the wrong reason once 1063 landed, since the
  control is in-memory only and nothing about that assertion exercised
  persistence. Rewrote to actually pick "Last 90 days" via
  `render_change`, then mount `/edit` fresh (the same thing a real
  reload does), and assert the reopened page still shows 90 selected.
  Confirmed failing: `filter_date_range`'s handler only does
  `assign(socket, :dashboard_date_range, range)`, and every mount
  hardcodes it back to `"30"` -- nothing persists the choice to the
  `Dashboard` record (which has no field for it at all: `name`,
  `description`, `built_in` only).
- **Default 30-day range when none is named (Story 74 rule 9 /
  criterion 1067) -- pass.** Rule: "When Dana does not name a date
  range, the agent uses the last 30 days ending yesterday." Nothing in
  `VizChat`'s system prompt or tool descriptions mentioned any default
  date range at all. Added a capture-based test asserting the real
  prompt mentions a 30-day default; confirmed failing, then fixed at
  a5e660d. Confirmed passing.

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
All 6 files exist; 5 pass end-to-end. Journey 6 has 15/16 passing as of
a5e660d, with 1 committed failing (a filter control's value doesn't
persist across a reopen -- Story 74 rule 8), handing the coder its
next work.
