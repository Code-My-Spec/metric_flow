# Data window disappears after new Run Now job completes

## Status

accepted

## Severity

low

## Scope

app

## Description

After clicking "Run Now," a new  CorrelationJob  was created. On page reload, the
 [data-role="data-window"]  span was empty: the page showed "Data window:" with no
date range. The newly enqueued job had no  data_window_start / data_window_end 
values set at creation time (these are typically populated when the worker runs and
completes). However, once a job is in  :pending  or  :running  state, it becomes
the "latest completed job" only after  completed_at  is set — so the summary bar
should still reference the previous completed job's data window, not the new pending
job. Investigation:  get_latest_correlation_summary/1  calls
 CorrelationsRepository.get_latest_completed_job/1 , which queries for
 status: :completed  and  order_by: [desc: :completed_at] . This should still return
the prior completed job (not the new pending one). However, the new job inserted by
Run Now appears to have been inserted with  status: :completed  (or the Oban worker
ran very quickly and updated status), causing the new job — which has no
 data_window_start  set — to become the latest completed job on page reload. Reproduced at:  http://localhost:4070/correlations  — after clicking Run Now and
reloading the page, "Data window:" shows an empty value.

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`
