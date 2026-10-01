# Qa Story Brief

## Tool

web

## Auth

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 8000 })
```

If `browser_fill` hangs/times out on these fields (seen intermittently this session), use `browser_click` then `browser_type` instead.

This worktree's dev server was 503ing at session start (`Phoenix.Ecto.PendingMigrationError` -- this story's own `CreateCorrelationGoalQueue` migration had never been run against `metric_flow_dev_wc_bd0baac8`). Fixed via `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate`, filed as issue f984bc70 (qa scope, same recurring per-worktree-DB class seen for stories 14/26/30/42 this session).

## Seeds

Use qa@example.com's own default account (owner, active subscription already confirmed working in story 24/26 sessions). No story-specific seed needed -- the Goals page reads whatever real metric names already exist for the active account via `Metrics.list_metric_names/1`.

If the active account has no metrics, switch to "Client Alpha" (account 14) or "Client Account Manager" (account 17), both of which have real synced metric data from earlier story 24/26 QA sessions.

## What To Test

- **Menu access (175/838)**: confirm a "Goals" link exists in the main nav and navigates to `/app/correlations/goals`.
- **Single-metric goal selection (176/839)**: on `/app/correlations/goals`, select a metric from the dropdown, click `[data-role='save-goal']`. Confirm a flash ("Goal metric saved. Correlation analysis started.") and redirect to `/app/correlations`. Confirm a new `correlation_jobs` row was created for the active account with `goal_metric_name` matching the selection (check via SQL).
- **Multiple single-metric goals built up over time (176's own wording -- "separate single-metric goal configurations, one at a time", not a multi-select)**: confirm the acceptance criteria's intent (one metric at a time, not a bulk multi-select picker) is satisfied by the primary `save_goal` form -- the page's *second* "Queue Multiple Goals" checkbox form is a different, additional mechanism (`queue_goals`/`run_correlations_for_multiple_goals`) for queuing several goals in one submission; test that one separately under 840 since both exist on the same page.
- **Multiple metrics as goals via queueing (840/844)**: check 2+ checkboxes in the "Queue Multiple Goals" section, submit. Confirm the flash text differs for >1 goal ("...started for the first metric; the rest are queued.") and that a `correlation_goal_queue` row was created for each metric beyond the first (check via SQL: `select * from correlation_goal_queue order by inserted_at desc limit 5`) -- this is the newly-migrated table, so this is also effectively confirming the migration fix landed correctly.
- **Highlighting in metric lists (177/841) -- verify this is a real feature, not a spex false-positive**: the spex for this criterion passes if `has_element?(view, "[data-role='goal-metric-badge']")` OR the raw html merely *contains the substring* "Goal" anywhere -- and the main nav's own "Goals" link (always rendered via the shared `Layouts.app` on every authenticated page) contains that substring regardless of whether any real per-metric badge exists. After selecting a goal, visit `/app/dashboards` (the page the spex itself checks) and specifically look for `[data-role='goal-metric-badge']` near the actual metric row/name -- not just "the word Goal appears somewhere on the page". If no such element exists anywhere outside the nav, this is a real gap even though the spex is green, and should be filed.
- **Modify goal later (178/842)**: after saving one goal, return to `/app/correlations/goals` and confirm the dropdown pre-selects the previously-saved goal (`determine_selected_goal/2` reads the latest correlation summary), then select a different metric and save again. Confirm the new goal takes effect (new correlation_jobs row, or the already-running guard if one is in flight).
- **Per-account persistence (179/843)**: confirm the saved goal is specific to the active account -- switch accounts and confirm the Goals page's pre-selected dropdown value differs (or is blank) for the other account, matching that account's own latest correlation job, not the first account's.
- **Queues correlation analysis (180/844)**: confirm `Correlations.run_correlations/2` (single goal) and `run_correlations_for_multiple_goals/3` (multi-goal) both actually create a `correlation_jobs` row with `status` that is not already `completed` at creation (i.e., it's queued/running, not synchronously finished) -- check via SQL immediately after submitting.
- **Already-running guard**: if a job is already in flight for the account when submitting another goal, confirm the "A correlation run is already in progress" flash appears instead of creating a duplicate job.
- **Insufficient-data guard**: if feasible, confirm the "Not enough data" flash appears for a metric with under 30 days of history (lower priority -- only test if a suitable fixture metric is quickly available; do not manufacture one if it requires significant setup, since this guard is simple and not the story's focus).

## Result Path

Findings are filed via `create_issue` as discovered; final result via `submit_qa_result`. No result.md file.

## Results

Menu access, single-goal save, goal modification/pre-select, per-account persistence, the multi-goal queueing form, and the already-running guard all verified correctly at the UI and DB level across two accounts (14 "Client Alpha", 17 "Client Account Manager").

Two real findings:

- **Critical** (`6aa8841a`): `CorrelationWorker` never receives `account_id` -- only `job_id`/`user_id` -- so `build_scope/1` resolves an arbitrary account via the old pre-26388c55 fallback instead of the job's real account. Every correlation job submitted through today's correctly-account-scoped LiveViews now fails 3x with `{:error, :not_found}` and is permanently discarded by Oban, leaving `correlation_jobs.status` stuck at `pending` forever. Reproduced on *both* test accounts (job 50 on account 17, job 51 on account 14) -- this isn't an edge case tied to one account, it's effectively universal now that the LiveView-side scoping fix means the active account is rarely the worker's arbitrary fallback account. This breaks the real intent of criterion 180/844: a goal selection "queues" a job record correctly, but the queued analysis itself never actually executes, so no correlation results are ever produced for any newly-selected goal in this session.
- **Medium** (`ee742e94`): criterion 177/841 (goal metrics highlighted/badged in metric lists) has no real implementation anywhere -- confirmed zero `[data-role='goal-metric-badge']` elements on `/app/dashboards` after saving a real goal. The criterion's own spex only passes via a weak `html =~ "Goal"` fallback that trivially matches the main nav's permanent "Goals" link text.

Also filed `f984bc70` (qa scope): this worktree's dev DB had not run story 23's own `CreateCorrelationGoalQueue` migration at session start, causing a total 503 outage until `mix ecto.migrate` was run.

Given the critical worker bug directly undermines the story's core purpose (a queued analysis that can never complete isn't a working feature), this pass is submitted as **fail** despite most of the surrounding UI mechanics working correctly.

## Results (retest, commit bdee81f)

**6aa8841a (critical worker account-scoping) confirmed fixed.** Submitted two fresh goals on account 17 (the account that failed every time last pass); both completed successfully (correlation_jobs 54 and 55, status=completed) instead of being stuck at pending and discarded. Criterion 180/844 now genuinely works for a non-default/switched-to account.

**ee742e94 (missing goal-metric badge) was fixed but the fix itself has the same root-cause bug it was meant to address.** `VisualizationLive.Editor` (where the badge now lives) never calls `Scope.put_account_id/2` anywhere in the file -- confirmed by grep and by `handle_params/3` reading `socket.assigns.current_scope` directly. Reproduced live: with account 14 (Client Alpha) active, the metric picker lists `qa_viz_test_a`/`qa_viz_test_b`, synthetic fixtures belonging to a *different* account (QA Test Account, id 21) from story 29's testing -- the picker's entire metric list is scoped to an arbitrary account, not the active one. The badge never renders for account 14's real, completed goal ("clicks", confirmed directly against `get_latest_correlation_summary(account_id: 14)` and present in the picker's own list) because the LiveView is comparing against the wrong account's goal metric. Filed as new high-severity issue `d4df9e43`.

Also hit a repeated browser-automation quirk this pass: `browser_select` (and even a direct JS `value=`/`dispatchEvent('change')`) intermittently failed to change this specific `<select>`'s value before submission, silently submitting the previously-pre-selected option instead -- not an app bug (confirmed the server-side `phx-change` mechanism itself works correctly when verified step-by-step), but cost significant time triangulating; worth a note for future sessions testing this page.

Submitting as **partial**: the critical blocker is resolved, but a new real finding (account-scoping gap in the editor's badge) replaces it.

## Results (retest 2, commit af6106e)

**d4df9e43 confirmed fixed.** `VisualizationLive.Editor.mount/3` now calls `Scope.put_account_id/2` with `active_account_id`, exactly the pattern already used by `Goals`/`CorrelationLive.Index`/`CorrelationWorker`.

Live verification across both test accounts:
- Account 14 (Client Alpha): badge now renders on "impressions" in the metric picker. Confirmed via direct DB query (`correlation_jobs` id 57, account_id=14, goal_metric_name="impressions", status=completed, inserted later than the earlier "clicks" job) that this is genuinely the account's current latest goal -- the goal legitimately changed since the last pass due to additional correlation runs from other stories' QA sessions, it isn't a regression.
- Account 17 (Client Account Manager): switching accounts in the same browser session correctly removes the badge entirely (no element renders for any metric), because account 17's own latest goal (`QUICKBOOKS_ACCOUNT_DAILY_CREDITS`, a leftover synthetic value from earlier QuickBooks fixture testing) doesn't match any current metric name -- a pre-existing fixture-naming artifact unrelated to this story, not a new finding.

Note for future sessions: `Metrics.list_metric_names/2` (and the underlying `metric_repository.ex` queries) filter purely by `scope.user_id` -- the metrics table has no `account_id` column at all. The picker's metric *list* is therefore identical regardless of active account (same user owns both); only the *badge comparison* (which reads the account-scoped correlation summary) actually depends on which account is active. This explains why `qa_viz_test_a`/`qa_viz_test_b` (fixtures from a different account's story 29 session) appear in the list under both accounts 14 and 17 -- that's expected per-user scoping, not a leak introduced by this fix.

Submitting as **pass**: both filed issues for this story (6aa8841a, d4df9e43) are now confirmed resolved.
