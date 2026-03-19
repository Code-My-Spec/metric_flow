# Insufficient-data-warning badge not shown when account has existing correlation data

## Status

resolved

## Severity

medium

## Scope

app

## Description

When clicking "Run Now" returns  {:error, :insufficient_data} , the LiveView sets  @run_error = :insufficient_data  and shows a flash error message. The source also renders  [data-role="insufficient-data-warning"]  badge, but this element is nested inside  [data-role="no-data-state"] , which only renders when  @summary.no_data  is true. In practice, if an account has existing correlation results (any prior run),  @summary.no_data  is false — the data-state view is shown. When the user clicks Run Now and gets an  :insufficient_data  error, the flash appears but the badge does not, because its container  [data-role="no-data-state"]  is hidden. To reproduce: Log in to an account that has prior correlation results but whose underlying metric data is insufficient for a new run Click Run Now Flash error: "Not enough data to run correlations. At least 30 days of metric data is required." appears [data-role="insufficient-data-warning"]  does not appear (it is inside the hidden  no-data-state  div) The badge should be conditionally rendered in the raw-mode or summary area so it appears regardless of whether the no-data empty state is shown.

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`

## Resolution

Moved the insufficient-data-warning badge into the raw-mode section of the correlation LiveView so it renders regardless of whether the no-data empty state is shown. The badge (data-role="insufficient-data-warning") was previously nested inside data-role="no-data-state" which only renders when @summary.no_data is true. Added a second instance of the badge inside the raw-mode div (after the summary bar, before filter controls) conditioned on @run_error == :insufficient_data. File changed: lib/metric_flow_web/live/correlation_live/index.ex. Verified by running MIX_ENV=test mix agent_test — 2729 tests, 7 pre-existing failures, no new failures introduced.
