# QA Result

Story 447 — Automated Correlation Analysis.

## Status

partial

## Scenarios

### Scenario 1 — No-data empty state

pass

The /correlations LiveView renders the no-data-state element when summary.no_data is true and no job is running. The no-data paragraph contains: "No correlations found", "at least 30 days of data points", "daily aggregated Pearson correlation coefficients", and "Last calculated: never — need at least 30 days of data before correlations can run". The Connect Integrations link navigates to /integrations. The correlation-results wrapper is always present in the template, unconditionally rendered.

The BDD spex for criterion 4113 (minimum data threshold) passed via mix spex.

Unauthenticated access to /correlations returned HTTP 302 — correct redirect to login.

Browser screenshots were not captured — Vibium MCP tools were unavailable in this environment.

### Scenario 2 — Page header and mode toggle

pass

Template contains h1 "Correlations", subtitle "Which metrics drive your goal?", mode-toggle with mode-raw and mode-smart buttons, and the run-correlations button. The mode-raw button renders with btn-primary class (Raw is the default mode at mount). The run-correlations button is not disabled when no job is running.

### Scenario 3 — Raw mode correlation results table displayed

pass

When mode is raw and summary.no_data is false (the state for qa@example.com after seeding), the template renders the raw-mode section. The summary bar contains goal-metric showing "Goal: revenue", last-calculated from job.completed_at, data-window with the 90-day window, and data-points showing "90 data points".

BDD spex for criterion 4108 (auto calculates correlations) passed via mix spex.

### Scenario 4 — Results table metric entries with coefficient and optimal lag

pass

Template renders one correlation-row per result. With 5 seeded results all rows appear. Coefficient coloring: positive values get text-success, negative get text-error. The income row (coefficient -0.38) renders with text-error. Strength badges: clicks (0.82) and spend (0.74) render as Strong; impressions (0.51) as Moderate; income and sessions as Weak. Lag cell: optimal_lag == 0 renders "Same day"; the income row with optimal_lag 0 renders "Same day" correctly.

BDD spex for criteria 4110 and 4111 (lag detection, optimal lag selection) passed via mix spex.

### Scenario 5 — All metric types without segregation

pass

Template has no marketing-correlations or financial-correlations data-role elements. All results render into the single results-table. Financial metrics (QuickBooks income) and marketing metrics (Google Ads clicks and spend, Facebook Ads impressions, Google Analytics sessions) appear in the same unified table.

BDD spex for criterion 4114 passed via mix spex.

### Scenario 6 — Sorting the results table

pass

Sort event handler sets sort_by to the clicked column and sort_dir to desc. Clicking the same column again toggles direction. The active column header renders data-sort-active="true" and a directional arrow. Default sort at mount is coefficient descending using abs(). Four sortable columns: metric_name, coefficient, lag, platform. Data Points column is non-sortable.

### Scenario 7 — Platform filter

pass

Platform filter buttons render for each distinct provider in results. With 4 distinct providers (google_ads, facebook_ads, quickbooks, google_analytics), 4 provider buttons plus All Platforms are rendered. The filter handler uses String.to_existing_atom — all four provider atoms are defined in CorrelationResult and loaded at compile time, so they exist in the BEAM atom table at event time. All Platforms gets btn-primary when platform_filter is nil; provider buttons get btn-primary on atom match.

### Scenario 8 — Run Now insufficient data response

pass

The run_correlations event handler calls Correlations.run_correlations/2, which returns insufficient_data error when fewer than 2 metric names exist. For qa-member@example.com (no seeded metrics), this path fires. The error flash reads "Not enough data to run correlations. At least 30 days of metric data is required." and the insufficient-data-warning badge renders with "Insufficient data — 30 days of metrics required".

BDD spex for criterion 4113 (minimum data threshold) passed via mix spex.

### Scenario 9 — Smart mode opt-in card

pass

The set_mode event sets mode assign to smart. Template renders the smart-mode section. When ai_suggestions_enabled is false (mount default), the opt-in card renders with h2 "Smart Mode", explanatory body text, and the enable-ai-suggestions button.

### Scenario 10 — Smart mode enable AI suggestions and submit feedback

pass

The enable_ai_suggestions event sets ai_suggestions_enabled to true, revealing the ai-suggestions-enabled badge, ai-recommendations block, and ai-feedback-section with feedback buttons. The submit_smart_feedback event sets ai_feedback_submitted to true, hiding the feedback buttons and showing the feedback-confirmation element with a badge-success checkmark.

### Scenario 11 — Job running banner

pass

The job-running-banner element renders conditionally when job_running is true, showing a spinner and "Correlation analysis is running. This page will reflect the latest results once complete." The run-correlations button has disabled set when job_running is true and renders a loading spinner inside. At mount with no pending/running job, the button is enabled. The schedule_daily_correlations function in the Correlations context is called by Oban cron after daily data sync.

## Evidence

Screenshots were not captured — Vibium MCP browser tools were not available in this environment. All scenarios were verified via:
- mix spex against all 7 BDD spec files: 7 tests, 0 failures
- Source code review of lib/metric_flow_web/live/correlation_live/index.ex
- Seed script output confirming data insertion via mix run priv/repo/qa_seeds_447.exs
- curl confirming unauthenticated redirect (302) at /correlations

## Issues

### Vibium MCP browser tools unavailable

#### Severity
MEDIUM

#### Scope
QA

#### Description
The mcp__vibium__browser_launch tool was not available in this Claude Code environment, returning "No such tool available". All 11 scenarios were verified by source code review and mix spex execution rather than live browser interaction. No screenshots were captured.

To fix: confirm the Vibium MCP server is configured in the Claude Code MCP settings. Once available, re-run the test plan to capture screenshots and exercise live event handling.
