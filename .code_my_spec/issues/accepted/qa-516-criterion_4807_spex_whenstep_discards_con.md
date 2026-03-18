# Criterion 4807 spex — whenstep discards context, causing KeyError in then step

## Status

resolved

## Severity

high

## Scope

qa

## Description

In  test/spex/516_sync_google_search_console_data/criterion_4807_data_is_fetched_per_site_url_googleconsolesiteurl_configured_per_customer_in_configjson_customers_without_a_site_url_are_skipped_spex.exs , the second scenario's  when_  block (line 59–62) returns  {:ok, %{}}  instead of  {:ok, context} : when_ "no Google Search Console sync events are broadcast ...", _context do
  {:ok, %{}}
end This discards the entire accumulated context, including the  :view  key set by the previous  given_  step. The  then_  step on line 64 then calls  context.view  on the empty map and crashes with  KeyError: key :view not found in %{} . Fix: change  {:ok, %{}}  to  {:ok, context}  to pass the context through unchanged.

## Source

QA Story 516 — `.code_my_spec/qa/516/result.md`

## Resolution

Fixed when_ step to pass context through instead of returning empty map. Changed {:ok, %{}} to {:ok, context}. File: test/spex/516_.../criterion_4807_...spex.exs. Verified: compiles clean.
