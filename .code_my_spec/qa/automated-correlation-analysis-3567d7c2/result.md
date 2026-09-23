# QA Result

## Status

partial

## Scenarios

### Scenario 1: No-data empty state

fail

The no-data empty state could not be tested because `qa-member@example.com` shares
the same first account ("QA Test Account") as `qa@example.com`. The seed script
`priv/repo/qa_seeds_447.exs` resolves `qa@example.com`'s account via
`Accounts.get_personal_account_id/1`, which returns the first `account_id` in the
`account_members` table for that user — which is "QA Test Account." Since
`qa-member@example.com` is also a member of "QA Test Account," their
`get_personal_account_id` call returns the same account, and they see the same
correlation data.

When navigating to `/correlations` as `qa-member@example.com`, the page shows the
full Raw mode table with all 5 seeded results — the no-data empty state is not
rendered. The `[data-role="no-data-state"]` element was absent, and the raw mode
table was visible with the seeded correlation results.

Screenshot: `.code_my_spec/qa/447/screenshots/no-data-state.png` (shows data state for qa-member, not the empty state)

### Scenario 2: Page header and mode toggle present

pass

Navigated to `/correlations` as `qa@example.com`. Verified:
- `h1` reads "Correlations"
- Subtitle reads "Which metrics drive your goal?"
- `[data-role="mode-toggle"]` present
- `[data-role="mode-raw"]` has class `btn btn-primary btn-sm` (active by default)
- `[data-role="mode-smart"]` present
- `[data-role="run-correlations"]` button present and enabled

Screenshot: `.code_my_spec/qa/447/screenshots/page-header.png`

### Scenario 3: Raw mode — correlation results summary bar

pass

- `[data-role="raw-mode"]` visible
- `[data-role="correlation-results"]` present
- `[data-role="correlation-summary"]` rendered
- `[data-role="goal-metric"]` shows "Goal: revenue"
- `[data-role="last-calculated"]` shows "Last calculated 4 minutes ago"
- `[data-role="data-window"]` shows "Data window: 2025-12-16 to 2026-03-15"
- `[data-role="data-points"]` shows "90 data points"

Screenshot: `.code_my_spec/qa/447/screenshots/raw-mode-summary.png`

### Scenario 4: Results table — metric entries with coefficient and lag

pass

- `[data-role="results-table"]` present
- Five `[data-role="correlation-row"]` rows found
- `[data-metric="clicks"]` row shows: coefficient `0.82`, strength badge "Strong", lag "7 days", platform "Google Ads"
- `[data-metric="income"]` row shows: coefficient `-0.38`, class `text-error` (negative coefficient colored correctly), lag "Same day" (optimal_lag == 0), platform "QuickBooks"

Screenshot: `.code_my_spec/qa/447/screenshots/results-table.png`

### Scenario 5: Unified results — no segregation

pass

- `[data-role="marketing-correlations"]` absent (not in DOM)
- `[data-role="financial-correlations"]` absent (not in DOM)
- All 5 metrics (including `income` from QuickBooks and `sessions` from Google Analytics) appear in the same unified table

Screenshot: `.code_my_spec/qa/447/screenshots/unified-results.png`

### Scenario 6: Sorting

pass

- Clicked `[data-sort-col="metric_name"]`; `data-sort-active="true"` set, arrow "↓" shown
- Clicked again; sort direction toggled to "↑"
- Clicked `[data-sort-col="lag"]`; `data-sort-active="true"` set on Lag header

Screenshots: `.code_my_spec/qa/447/screenshots/sorted-by-metric.png`, `.code_my_spec/qa/447/screenshots/sorted-by-lag.png`

### Scenario 7: Platform filter

pass

- `[data-role="platform-filter"]` present
- "All Platforms" button has `btn-primary` class (active by default)
- Clicked "Google Ads" filter: only 2 rows shown (`clicks` and `spend`)
- Clicked "All Platforms": all 5 rows shown again

Screenshot: `.code_my_spec/qa/447/screenshots/filtered-google-ads.png`

### Scenario 8: Run Now — insufficient data response

fail

Cannot test — `qa-member@example.com` shares the same account as `qa@example.com`
and has access to the same seed data. When "Run Now" was clicked as `qa@example.com`,
the system found sufficient metric data (`Metrics.list_metric_names/1` returned 2+
metrics), so a correlation job was enqueued with `:ok` rather than returning
`:error, :insufficient_data`. No insufficient data error or
`[data-role="insufficient-data-warning"]` badge was triggered.

The insufficient data path (fewer than 2 metric names) requires an account with no
integrated metrics — which is not achievable with the current seed setup since both
users share the same account and that account has existing metric data from prior
sync runs.

Screenshot: `.code_my_spec/qa/447/screenshots/run-correlations-click.png`

### Scenario 9: Smart mode — opt-in card

pass

- Clicked `[data-role="mode-smart"]`
- `[data-role="smart-mode"]` visible
- H2 "Smart Mode" present
- Explanatory paragraph present
- `[data-role="enable-ai-suggestions"]` button present

Screenshot: `.code_my_spec/qa/447/screenshots/smart-mode-optin.png`

### Scenario 10: Smart mode — enable AI suggestions and submit feedback

pass

- Clicked `[data-role="enable-ai-suggestions"]`
- `[data-role="ai-suggestions-enabled"]` badge appeared ("AI Suggestions enabled")
- `[data-role="ai-recommendations"]` block visible with H3 "AI Recommendations"
- `[data-role="ai-feedback-section"]` present
- `[data-role="feedback-helpful"]` and `[data-role="feedback-not-helpful"]` buttons shown
- Clicked `[data-role="feedback-helpful"]`
- `[data-role="feedback-confirmation"]` appeared with checkmark and "Thanks for your feedback" text
- Feedback buttons hidden after submission

Screenshots: `.code_my_spec/qa/447/screenshots/smart-mode-enabled.png`, `.code_my_spec/qa/447/screenshots/smart-mode-feedback-submitted.png`

### Scenario 11: Job running banner

pass

- Clicked `[data-role="run-correlations"]`; a correlation job was enqueued
- `[data-role="job-running-banner"]` appeared with "Correlation analysis is running..." message
- `[data-role="run-correlations"]` button was disabled while job running
- Loading spinner shown inline in the Run Now button

Screenshot: `.code_my_spec/qa/447/screenshots/job-running-banner.png`

## Evidence

- `.code_my_spec/qa/447/screenshots/no-data-state.png` — correlations page as qa-member (shows data, not empty state)
- `.code_my_spec/qa/447/screenshots/page-header.png` — page header with mode toggle and Run Now
- `.code_my_spec/qa/447/screenshots/raw-mode-summary.png` — summary bar with goal metric, timestamp, data window, data points
- `.code_my_spec/qa/447/screenshots/results-table.png` — full results table with all 5 correlation rows
- `.code_my_spec/qa/447/screenshots/unified-results.png` — unified table showing financial and marketing metrics together
- `.code_my_spec/qa/447/screenshots/sorted-by-metric.png` — table sorted by metric name (descending)
- `.code_my_spec/qa/447/screenshots/sorted-by-lag.png` — table sorted by lag column
- `.code_my_spec/qa/447/screenshots/filtered-google-ads.png` — platform filter active showing only Google Ads rows
- `.code_my_spec/qa/447/screenshots/run-correlations-click.png` — after clicking Run Now (job started, not insufficient data)
- `.code_my_spec/qa/447/screenshots/job-running-banner.png` — job running banner and disabled Run Now button
- `.code_my_spec/qa/447/screenshots/smart-mode-optin.png` — smart mode opt-in card
- `.code_my_spec/qa/447/screenshots/smart-mode-enabled.png` — AI suggestions enabled with recommendations and feedback buttons
- `.code_my_spec/qa/447/screenshots/smart-mode-feedback-submitted.png` — feedback confirmation after clicking Helpful

## Issues

### Seed script cannot create an isolated no-data user for Scenario 1

#### Severity
MEDIUM

#### Scope
QA

#### Description
The brief specifies testing the no-data empty state with `qa-member@example.com`
because "qa-member has no correlation data." However, both `qa@example.com` and
`qa-member@example.com` are members of "QA Test Account," and
`Accounts.get_personal_account_id/1` returns the first `account_id` from
`account_members` for any user — which is "QA Test Account" for both users. The
seed script `priv/repo/qa_seeds_447.exs` correctly seeds correlation data using
`get_personal_account_id(qa_user_scope)`, but because qa-member's first account is
also "QA Test Account," they see the same data.

To fix: the `qa_seeds_447.exs` script should ensure that the correlation data is
seeded to an account that qa-member does NOT belong to. One option is to create a
dedicated personal account (type: personal) for qa@example.com separately from the
shared team account, and seed correlation data to that personal account. Alternatively,
use a completely fresh user for the data state that is not a member of any account
that qa-member belongs to.

Repro: Log in as `qa-member@example.com`, navigate to `/correlations` — the full
Raw mode table is shown instead of the no-data empty state.

### Run Now "insufficient data" scenario not testable with current seed state

#### Severity
LOW

#### Scope
QA

#### Description
Scenario 8 requires triggering `{:error, :insufficient_data}` from `Correlations.run_correlations/2`,
which occurs when `Metrics.list_metric_names(scope)` returns fewer than 2 metric
names. The current database has existing metric records (from prior sync jobs) tied
to QA Test Account, so clicking Run Now returns `{:ok, job}` and starts a job
instead of returning the error response.

To fix: the `qa_seeds_447.exs` script should either (a) use a freshly created
account with zero metrics for this scenario, or (b) document that Scenario 8 is
best tested via a unit/integration test rather than browser QA, since the
insufficient data state requires controlled metric counts that are hard to guarantee
in a shared dev database.

### Data window disappears after new Run Now job completes

#### Severity
LOW

#### Scope
APP

#### Description
After clicking "Run Now," a new `CorrelationJob` was created. On page reload, the
`[data-role="data-window"]` span was empty: the page showed "Data window:" with no
date range. The newly enqueued job had no `data_window_start`/`data_window_end`
values set at creation time (these are typically populated when the worker runs and
completes). However, once a job is in `:pending` or `:running` state, it becomes
the "latest completed job" only after `completed_at` is set — so the summary bar
should still reference the previous completed job's data window, not the new pending
job.

Investigation: `get_latest_correlation_summary/1` calls
`CorrelationsRepository.get_latest_completed_job/1`, which queries for
`status: :completed` and `order_by: [desc: :completed_at]`. This should still return
the prior completed job (not the new pending one). However, the new job inserted by
Run Now appears to have been inserted with `status: :completed` (or the Oban worker
ran very quickly and updated status), causing the new job — which has no
`data_window_start` set — to become the latest completed job on page reload.

Reproduced at: `http://localhost:4070/correlations` — after clicking Run Now and
reloading the page, "Data window:" shows an empty value.
