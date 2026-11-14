# QA Journey Result

## Status

mixed

Journeys 1-5 from the plan were walked live against the running app
(`http://localhost:4070`, this worktree's dev server) and passed; each is
codified as a `Phoenix.LiveViewTest` module under `test/journeys/` (see
Phase 3 notes below) -- the prior attempt at this phase had pivoted to
unrelated BDD-spec fixes without actually executing any journey; this run
replaces that result. Journey 6 (Story 74, "Build a Screen with the Agent") was added and walked
across several coder stages: fail at commit 5d7b86d7 (no chat affordance at
all), pass for chat-builds-one-visualization at 684d9a0/4db2d04, pass for
draft autosave + reload persistence at 950932f -- and fail again at 950932f
for mixed widget types in one chat message, which still collapses into a
single Vega-Lite spec instead of separate dashboard elements. Re-walked at
d4a75d8 (2026-11-14): still fails, now with a precise root cause -- see
below. Missing-metric redirect, a named "Edit with agent" resume action, and
versioning/restore remain untested/unbuilt. The journey test stays red (multi-widget stage)
rather than green, since Story 74 isn't fully built. Some of this walking was
done outside `start_task`/`evaluate_task` because of a graph deadlock
(c2084903) that refused to re-offer `qa_journey` after a stage landed; see
Issues.

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

**Status:** partial (re-walked outside the task loop; graph deadlock c2084903
tracked separately, see Issues)

**First walk (commit 5d7b86d7):** fail at step 2. `/app/dashboards/new` was
the existing manual builder only ("Start from a template or blank canvas" +
"+ Add Visualization"), with no chat affordance anywhere. Screenshot:
`.code_my_spec/qa/journeys/screenshots/journey6_new_dashboard.png`.

**Re-walk (commit 4db2d04, this copy's app at `http://127.0.0.1:53149`):**
the coder landed the first stage. Logged in as `qa@example.com` and opened
`/app/dashboards/new`:

- **Chat builds a visualization from natural language -- pass.** A "Build
  with AI" panel (`[data-role='dashboard-chat-input']` /
  `[data-role='dashboard-chat-send-btn']`) is present. Sending "Show me a
  spend-over-time line chart" added a working line chart ("Spend Over
  Time", plotting `total_cost` by date) to the canvas, with the agent's
  reply explaining the metric choice and offering follow-ups. Screenshot:
  `.code_my_spec/qa/journeys/screenshots/journey6_stage2_chat_built_chart.png`.
- **Draft autosave on first build -- fail / not built (commit 4db2d04).**
  Reloading the page after the chart was built returned to the blank
  "/new" state with the chat history and chart gone; the URL never moved
  off `/app/dashboards/new`. No dashboard record was created until an
  explicit "Save Dashboard" click.
- **Mixed widget types in one request, missing-metric redirect to
  integrations, "Edit with agent" resuming a saved dashboard's history, and
  per-change versioning with restore -- not independently re-tested at
  4db2d04** (per main's guidance, since only `dashboard_live/editor.ex`
  changed in 684d9a0).

**Second re-walk (commit 950932f):** the coder landed draft autosave.

- **Draft autosave on first build -- pass.** Building the same line chart
  via chat created a real `Dashboard` (id 8, "Untitled Dashboard",
  visible under My Dashboards) with no explicit save. Visiting
  `/app/dashboards/8/edit` directly (simulating a reload/reopen) showed
  the same chart and the full chat history ("You: Show me a
  spend-over-time line chart" / "Agent: ..."), satisfying Story 74 rule 1
  and the "refreshing the page shows the same dashboard" scenario.
  Screenshots:
  `.code_my_spec/qa/journeys/screenshots/journey6_stage3_after_build_950932f.png`,
  `.code_my_spec/qa/journeys/screenshots/journey6_stage3_reopened_edit8.png`.
- **Mixed widget types in one message -- fail / not built.** Asked (on the
  same persisted dashboard) for "a line chart of revenue over time and a
  headline stat of total conversions" in one message, after an earlier
  turn had already added a stat tile. The agent's reply described adding
  "three parts" (two headline stats side by side plus a line chart below
  them), but the canvas gained exactly one new card, labeled "Custom" /
  "line" -- the three parts are crammed into a single Vega-Lite spec
  rather than created as separate stat-tile/chart dashboard elements.
  `add_visualization_from_chat_spec/2` only ever appends one visualization
  per chat turn, so a message asking for several distinct widget types
  cannot produce several distinct widgets yet, contrary to Story 74 rule
  2's scenario ("the dashboard shows a stat tile, a line chart and a
  table in a layout"). Screenshot:
  `.code_my_spec/qa/journeys/screenshots/journey6_stage4_multiwidget_gap.png`.
- **Missing-metric redirect to integrations, "Edit with agent" as a named
  resume action (distinct from just visiting `/edit`), and per-change
  versioning with restore -- still not independently tested/built.**

**Third re-walk (commit d4a75d8, "Support multiple widgets from one chat
turn", 2026-11-14):** restarted this copy's app to serve d4a75d8 and
re-walked build / reload / multi-widget live as `qa@example.com`.

- **Chat builds a visualization, draft autosave + reload -- still pass,
  no regression.** Logged in, opened `/app/dashboards/new`, built a chart
  via chat; standard behavior unchanged from the prior two stages.
- **Mixed widget types in one message -- still fails, now with a precise
  root cause.** Asked "Show me a headline stat of total conversions and a
  line chart of cost over time" (one message). The agent replied it had
  created "two stacked views" and explained each, but the canvas still
  gained exactly **one** card (`data-role="visualization-card"` count:
  1), labeled "Custom" / "line". Inspecting that card's `data-spec`
  attribute showed a single Vega-Lite spec using `vconcat` to stack a text
  mark (the headline) over a line mark (the chart) -- a real improvement
  over the earlier "three parts crammed into one spec losing information"
  failure mode, but still one combined visualization, not two independent,
  separately-draggable/removable dashboard elements as Story 74 rule 2's
  scenario describes.

  Followed up explicitly in the same chat: "Please add two separate
  widgets to this dashboard: a headline stat tile for total clicks, and a
  separate line chart widget for cost over time. They should be two
  independent dashboard elements, not one combined chart." The agent's
  reply is the most useful finding of this walk: *"I can't add two
  independent widgets with the tools I have. `update_spec` reads and
  writes one Vega-Lite spec, and I have no tool to create or manage
  separate dashboard elements. If I put both in that spec, they would be a
  single combined chart, which you said you don't want."* It then offered
  two options, both acknowledging it cannot satisfy the request: use the
  current spec for one widget and let the user create the other via the
  dashboard's own "add widget" flow, or keep the combined chart.

  Investigating the backend side (not just the live walk) found the
  multi-widget mechanism d4a75d8 actually added: the `:command_runner`
  test double for this stage (`VizChatStub.generate_initial/0`) scripts
  the model calling `update_spec` **twice** in one turn (two tool calls,
  two different specs), and the backend now creates a separate dashboard
  element per `update_spec` call within a turn instead of overwriting --
  that mechanism does work when exercised directly via ExUnit. The gap is
  narrower than "the backend can't do it": **the backend can, but the
  deployed model is never told it can call `update_spec` more than once
  per turn**, so the live model always reaches for `vconcat` (or declines)
  instead. This is a prompt / tool-description gap, not a persistence or
  rendering bug.

  The existing committed ExUnit test for this stage
  (`test/journeys/build_a_screen_with_the_agent_test.exs`, "a single chat
  message naming two distinct widget types produces two widgets") was
  passing against d4a75d8 before this walk, but only because it reused
  `VizChatStub.generate_initial/0` -- the unrealistic two-separate-calls
  double -- giving a false-green signal for the live behavior actually
  observed. Fixed as part of this walk: added
  `VizChatStub.generate_multi_widget_combined/0`, which reproduces the
  single-`vconcat`-spec response confirmed live (also had to route it
  through `ClaudeCodeStub.completed_tool_call/3` + `sequence/1` rather
  than a bare `tool_call/3` -- a bare one never reaches `:end_turn`, so
  the agent loop kept re-calling `update_spec` with the same spec until a
  turn cap, producing 25 duplicate cards in an early version of this fix,
  caught by inspecting the mismatch rather than accepting it). The test
  now correctly fails (`length(cards)`: `1`, expected `2`), matching the
  live result exactly. Per the walk convention, the failing test is left
  committed and no issue filed for it -- it's the coder's next work item,
  specifically on the AI system prompt / tool description for `VizChat`,
  not on rendering or persistence.

  Screenshot: `.code_my_spec/qa/journeys/screenshots/journey6_stage5_vconcat_gap.png`.

- **Missing-metric redirect to integrations, "Edit with agent" as a named
  resume action, and per-change versioning with restore -- still not
  independently tested/built; not re-attempted this walk since the
  multi-widget stage ahead of them is still red.**

Not a regression anywhere tested: everything that worked before still
works, and all capabilities tested to date work as described except
multi-widget composition. Multi-widget composition (now understood as a
prompt/tool-description gap, not a backend limitation), missing-metric
guidance, and versioning/restore still have no code (or prompt) to attach
to and remain open coder work, tracked via the still-committed failing test
rather than a new issue.

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

None newly filed against the application -- this run exercised already-
shipped, previously-QA'd surfaces (plus the now-better-understood
multi-widget gap, already tracked via the failing test) and found no new
application defects.

## Phase 3 note

Per John's decision (answer to question `5df24200`), journeys are codified
as `Phoenix.LiveViewTest` modules under `test/journeys/`, not Wallaby --
consistent with the project's e2e testing ADR, which does not use Wallaby.
All 6 files exist; 5 pass end-to-end, and journey 6 has 2/3 passing with the
third committed failing at the multi-widget stage as described above.
