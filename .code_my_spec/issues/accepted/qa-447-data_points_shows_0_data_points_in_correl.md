# Data points shows "0 data points" in correlation summary bar

## Status

accepted

## Severity

low

## Scope

app

## Description

The summary bar's  [data-role="data-points"]  shows "0 data points" for the QA Test Account even though 27 correlation result rows are visible in the table. The team account's completed  CorrelationJob  record has  data_points: 0  while the actual results exist. This is a data consistency issue — the job's  data_points  field is not updated to reflect the actual number of results or metric data points used in the calculation. Users see "0 data points" which is misleading when results are clearly present. Reproduced at:  http://localhost:4070/correlations  logged in as  qa@example.com  (QA Test Account active).

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`
