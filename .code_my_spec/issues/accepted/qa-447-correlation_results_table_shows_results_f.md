# Correlation results table shows results from all jobs, not only the latest

## Status

resolved

## Severity

medium

## Scope

app

## Description

The  /correlations  page displays correlation results from ALL completed jobs for the account, not just the most recent one. This causes duplicate metric entries when multiple correlation jobs have run. Observed behavior:  The table shows 27 rows including duplicate entries for screenPageViews, newUsers, clicks, ctr, cost, impressions, conversions, average_cpc, bounceRate, and averageSessionDuration — each appearing twice with slightly different coefficients (from two different job runs). Root cause:  In  MetricFlow.Correlations.get_latest_correlation_summary/1  (line 95 of  lib/metric_flow/correlations.ex ), the results are loaded with: results = CorrelationsRepository.list_correlation_results(scope, []) This fetches all results for the account without filtering by  correlation_job_id . The summary header metadata (last calculated, data window, data points) comes from only the latest job, but the table rows mix results from all jobs. Expected behavior:  Only results linked to the latest completed job should be displayed. Fix:  Pass  job.id  to  list_correlation_results/2  (or add a filter option) so results are scoped to the specific job being displayed. Affected file:   lib/metric_flow/correlations.ex:95

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`

## Resolution

Fixed correlation results table showing results from all jobs by: (1) adding correlation_job_id filter option to CorrelationsRepository.list_correlation_results/2 via a new maybe_filter_job/2 private helper; (2) updating get_latest_correlation_summary/1 in correlations.ex to pass [correlation_job_id: job.id] when fetching results, scoping them to the latest completed job only. Files changed: lib/metric_flow/correlations/correlations_repository.ex, lib/metric_flow/correlations.ex. Verified with MIX_ENV=test mix agent_test (126 correlations tests pass, no regressions).
