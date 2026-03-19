# Duplicate Derived metric rows in correlation results table

## Status

resolved

## Severity

medium

## Scope

app

## Description

The Raw mode results table displays duplicate rows for several "Derived" provider metrics. The following metrics appear twice in the table with near-identical (but occasionally slightly different) coefficient values: screenPageViews  (Derived): 0.99 and 0.99 newUsers  (Derived): 0.97 and 0.97 clicks  (Derived): 0.87 and 0.86 ctr  (Derived): 0.82 and 0.80 cost  (Derived): 0.78 and 0.77 impressions  (Derived): 0.78 and 0.77 conversions  (Derived): 0.74 and 0.73 average_cpc  (Derived): 0.67 and 0.65 bounceRate  (Derived): 0.52 and 0.50 averageSessionDuration  (Derived): 0.31 and 0.29 This indicates duplicate  CorrelationResult  records exist in the database for the same metric name under the "Derived" provider, likely from multiple correlation runs creating new records rather than upserting. The deduplication should happen either at the database level (unique index on account_id + metric_name + provider) or in  get_latest_correlation_summary/1  by filtering to the most recent run's results only. Reproduced at:  http://localhost:4070/correlations  with  qa@example.com .

## Source

QA Story 448 — `.code_my_spec/qa/448/result.md`

## Resolution

Fixed duplicate CorrelationResult rows by scoping list_correlation_results to the latest completed job's ID in get_latest_correlation_summary/1. Added correlation_job_id filter support to CorrelationsRepository.filter_results/2 via a new maybe_filter_job/2 helper. Files changed: lib/metric_flow/correlations.ex (pass correlation_job_id: job.id to list_correlation_results), lib/metric_flow/correlations/correlations_repository.ex (add maybe_filter_job/2 and wire it into filter_results/2). Verified by running MIX_ENV=test mix agent_test on all 114 correlation tests with 0 failures.
