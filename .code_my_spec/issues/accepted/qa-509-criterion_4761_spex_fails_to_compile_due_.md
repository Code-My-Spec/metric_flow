# criterion_4761 spex fails to compile due to overly long test description

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The file  test/spex/509_sync_google_analytics_4_data/criterion_4761_ga4_runreport_10_metric_limit_chunked_fetch_and_merge_by_date_spex.exs  fails to compile with an Erlang atom table overflow error when the Elixir compiler tries to derive a function name from the spex description string. The description is: "Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is equivalent to what a single-request response would contain" Erlang internally calls  list_to_atom/1  on this string to generate an internal function name for the test, which exceeds the system atom table limit. The stack trace shows the failure in  v3_core.erl  during compilation. Steps to reproduce:  mix test test/spex/509_sync_google_analytics_4_data/criterion_4761_ga4_runreport_10_metric_limit_chunked_fetch_and_merge_by_date_spex.exs Fix: Shorten the  spex "..."  description string in the module. For example:  spex "GA4 runReport 10-metric limit: results from chunked fetches are merged by date before storage" . The test logic itself (scenarios) is correct and covers the required behavior.

## Source

QA Story 509 — `.code_my_spec/qa/509/result.md`

## Resolution

Shortened the spex description string from 230+ chars to 80 chars to avoid Erlang atom table overflow during compilation. File: test/spex/509_.../criterion_4761_...spex.exs. Verified: mix compile succeeds.
