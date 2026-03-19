# QA seed 447 is not idempotent when real jobs run after seeding

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The  priv/repo/qa_seeds_447.exs  seed script creates a completed  CorrelationJob  if none exists. Once a real correlation worker run creates a newer completed job (with 0 results for the test account), the seed script reuses the older seeded job on subsequent runs. The  get_latest_correlation_summary  function returns the newest completed job, which is now the real empty job, hiding the seeded results. Observed behavior:   [data-role="data-points"]  shows "0 data points" and no correlation rows appear in the results table — the five seeded results (clicks, spend, impressions, income, sessions) are not displayed. Root cause:  The seed idempotency check at line 60–66 returns the first existing completed job (ordered by  inserted_at desc ). After a real run adds a newer completed job, the seed's existing-job check returns the old seeded job (still the same branch), but the LiveView picks up the newer real job as the latest. Fix:  The seed script should always insert a new job with  completed_at  set to  DateTime.utc_now()  (ensuring it is the most recent) and delete or supersede any older seeded jobs. Alternatively, use a sentinel marker (e.g., a specific  goal_metric_name  value like  "qa_test_revenue" ) so the seeds always reset to a known state rather than reusing any existing completed job. Affected file:   priv/repo/qa_seeds_447.exs:60–96

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`

## Resolution

Rewrote qa_seeds_447.exs to always delete previous QA-seeded completed jobs (where goal_metric_name = 'revenue') and their results, then insert a fresh job with completed_at set to DateTime.utc_now(). This ensures the seeded job is always the most recent completed job when the LiveView calls get_latest_completed_job, regardless of any real correlation worker runs that may have added newer empty jobs since the previous seed run. File changed: priv/repo/qa_seeds_447.exs.
