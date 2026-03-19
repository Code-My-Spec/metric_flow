# Qa Result

## Status

pass

## Scenarios

### Scenario 1: No-data empty state

pass

Logged in as `qa-empty@example.com` and navigated to `/correlations`. The
`[data-role="correlation-results"]` wrapper was present and
`[data-role="no-data-state"]` was visible. The H2 heading read "No Correlations
Yet". The body paragraph contained "30 days", "daily aggregated", and
"Last calculated: never — need at least 30 days of data before correlations can
run." The "Connect Integrations" button was present and pointed to `/integrations`.
No raw-mode table was shown.

Evidence: `.code_my_spec/qa/447/screenshots/no-data-state.png`

### Scenario 2: Page header and mode toggle present

pass

Logged in as `qa@example.com` and navigated to `/correlations`. The H1 read
"Correlations", the subtitle read "Which metrics drive your goal?".
`[data-role="mode-toggle"]` was present. `[data-role="mode-raw"]` had class
`btn btn-primary btn-sm` (active default). `[data-role="mode-smart"]` existed.
`[data-role="run-correlations"]` was present and enabled.

Evidence: `.code_my_spec/qa/447/screenshots/page-header.png`

### Scenario 3: Raw mode — correlation results table displayed

pass

`[data-role="raw-mode"]` was visible. `[data-role="correlation-results"]` was
present. `[data-role="correlation-summary"]` was shown. `[data-role="goal-metric"]`
read "Goal: revenue". `[data-role="last-calculated"]` was present showing "just
now". `[data-role="data-window"]` showed "Data window: 2025-12-19 to 2026-03-18".
`[data-role="data-points"]` showed "90 data points".

Evidence: `.code_my_spec/qa/447/screenshots/raw-mode-summary.png`

### Scenario 4: Results table — metric entries with coefficient and optimal lag

pass

`[data-role="results-table"]` was present. Five `[data-role="correlation-row"]`
rows were shown. The "clicks" row (`[data-metric="clicks"]`) showed coefficient
`0.82`, strength badge "Strong", lag "7 days", and platform badge "Google Ads".
The "income" row (`[data-metric="income"]`) showed coefficient `-0.38` with
`text-error` class, lag "Same day" (optimal_lag == 0), and platform badge
"QuickBooks".

Evidence: `.code_my_spec/qa/447/screenshots/results-table.png`

### Scenario 5: Correlation results include all metric types without segregation

pass

No `[data-role="marketing-correlations"]` section existed. No
`[data-role="financial-correlations"]` section existed. Financial metric `income`
(QuickBooks) and marketing metric `clicks` (Google Ads) appeared together in the
same unified table.

Evidence: `.code_my_spec/qa/447/screenshots/unified-results.png`

### Scenario 6: Sorting the results table

pass

Clicked `[data-sort-col="metric_name"]` — `data-sort-active="true"` was set and
the sort arrow "↓" appeared. Clicked again — arrow changed to "↑" (direction
toggled). Clicked `[data-sort-col="lag"]` — `data-sort-active="true"` moved to
the Lag header.

Evidence: `.code_my_spec/qa/447/screenshots/sorted-by-metric.png`,
`.code_my_spec/qa/447/screenshots/sorted-by-lag.png`

### Scenario 7: Platform filter

pass

`[data-role="platform-filter"]` was present. "All Platforms" button had class
`btn btn-primary btn-sm` (active by default). Clicked the "Google Ads" filter
button — only 2 rows remained (clicks, spend), both with provider `:google_ads`.
Clicked "All Platforms" — all 5 rows were shown again.

Evidence: `.code_my_spec/qa/447/screenshots/filtered-google-ads.png`

### Scenario 8: Run Now button — insufficient data response

pass

As `qa-empty@example.com` on `/correlations`, clicked `[data-role="run-correlations"]`.
An error flash appeared: "Not enough data to run correlations. At least 30 days of
metric data is required." `[data-role="insufficient-data-warning"]` badge appeared
with text "Insufficient data — 30 days of metrics required".

Evidence: `.code_my_spec/qa/447/screenshots/run-insufficient-data.png`

### Scenario 9: Smart mode — opt-in card

pass

Clicked `[data-role="mode-smart"]`. `[data-role="smart-mode"]` section became
visible. The opt-in card showed H2 "Smart Mode" and the `[data-role="enable-ai-suggestions"]`
button was present.

Evidence: `.code_my_spec/qa/447/screenshots/smart-mode-optin.png`

### Scenario 10: Smart mode — enable AI suggestions and submit feedback

pass

Clicked `[data-role="enable-ai-suggestions"]`. `[data-role="ai-suggestions-enabled"]`
badge appeared with text "AI Suggestions enabled". `[data-role="ai-recommendations"]`
block was visible with "AI Recommendations" heading. `[data-role="ai-feedback-section"]`
was present. `[data-role="feedback-helpful"]` and `[data-role="feedback-not-helpful"]`
buttons were visible. Clicked `[data-role="feedback-helpful"]`.
`[data-role="feedback-confirmation"]` appeared and feedback buttons were hidden.

Evidence: `.code_my_spec/qa/447/screenshots/smart-mode-enabled.png`,
`.code_my_spec/qa/447/screenshots/smart-mode-feedback-submitted.png`

### Scenario 11: Job running banner (visual state)

pass

`[data-role="run-correlations"]` button existed and was enabled (not disabled)
with no active job running — baseline confirmed. The job-running banner
(`[data-role="job-running-banner"]`) was not visible since no job was active.

Evidence: `.code_my_spec/qa/447/screenshots/run-correlations-button.png`

## Evidence

- `.code_my_spec/qa/447/screenshots/no-data-state.png` — Empty state for qa-empty@example.com
- `.code_my_spec/qa/447/screenshots/run-insufficient-data.png` — Insufficient data error after Run Now
- `.code_my_spec/qa/447/screenshots/page-header.png` — Page header with mode toggle (qa@example.com)
- `.code_my_spec/qa/447/screenshots/raw-mode-summary.png` — Summary bar with goal, window, data points
- `.code_my_spec/qa/447/screenshots/results-table.png` — Full results table with 5 rows
- `.code_my_spec/qa/447/screenshots/unified-results.png` — Unified table (no marketing/financial split)
- `.code_my_spec/qa/447/screenshots/sorted-by-metric.png` — Table sorted by metric name column
- `.code_my_spec/qa/447/screenshots/sorted-by-lag.png` — Table sorted by lag column
- `.code_my_spec/qa/447/screenshots/filtered-google-ads.png` — Platform filter showing only Google Ads rows
- `.code_my_spec/qa/447/screenshots/smart-mode-optin.png` — Smart mode opt-in card before enabling AI
- `.code_my_spec/qa/447/screenshots/smart-mode-enabled.png` — Smart mode with AI suggestions enabled
- `.code_my_spec/qa/447/screenshots/smart-mode-feedback-submitted.png` — Feedback confirmation shown
- `.code_my_spec/qa/447/screenshots/run-correlations-button.png` — Run Now button baseline (not disabled)

## Issues

### Story 447 seed script inserts data for wrong account when user has multiple team accounts

#### Severity
MEDIUM

#### Scope
QA

#### Description

`priv/repo/qa_seeds_447.exs` inserts correlation data into the account named
"QA Test Account" (hardcoded by name lookup). However,
`CorrelationsRepository.get_account_id/1` calls
`Accounts.get_personal_account_id/1`, which runs:

```elixir
from(m in AccountMember, where: m.user_id == ^user.id, select: m.account_id, limit: 1)
```

This query has no `order_by` clause, so the database returns the first row by
insert order. For `qa@example.com`, that is account_id=14 ("Client Alpha") —
inserted before "QA Test Account" (account_id=21) — regardless of which account
was seeded.

As a result, after running `mix run priv/repo/qa_seeds_447.exs`, the
`/correlations` page showed "No correlations match the selected filter." and
"0 data points" because the LiveView loaded data for account_id=14 (no data)
instead of account_id=21 (seeded data).

The workaround used during this QA run was to manually insert the same seed data
directly into account_id=14 via a temporary script.

To fix: update `priv/repo/qa_seeds_447.exs` to query the account_id that
`get_personal_account_id` will resolve to for `qa@example.com` at runtime
(i.e., the first `account_members` row by insert order for that user), rather
than looking up "QA Test Account" by name. Alternatively, update the seed to
use `Accounts.get_personal_account_id/1` directly via the Scope helper.
