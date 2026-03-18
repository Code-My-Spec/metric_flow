# Spex criterion_4761 filename exceeds Erlang file loader limit (255 bytes)

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The spex file  test/spex/509_sync_google_analytics_4_data/criterion_4761_because_ga4s_runreport_endpoint_has_a_10-metric_limit_per_request_metrics_are_fetched_in_chunks_of_10_and_results_are_merged_by_date_before_storage_the_final_stored_data_is_equivalent_to_what_a_single-request_response_would_contain_spex.exs  has a filename that is exactly 255 characters long. On macOS, the filesystem allows filenames up to 255 characters, but the Erlang VM's file module fails with "a system limit has been reached" when attempting to load a file at this exact boundary. Running  mix spex  against the story 509 directory produces the error:  Failed to load [path]: a system limit has been reached . The file content is valid and the test scenarios inside it are meaningful. The fix is to shorten the filename — for example, by removing "the_final_stored_data_is_equivalent_to_what_a_single-request_response_would_contain" from the suffix.

## Source

QA Story 509 — `.code_my_spec/qa/509/result.md`

## Resolution

Renamed spex file from 255-char name to criterion_4761_ga4_runreport_10_metric_limit_chunked_fetch_and_merge_by_date_spex.exs. Module name inside unchanged. File now loads in Erlang VM.
