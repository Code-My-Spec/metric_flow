# No navigation entry point to Goal Metrics from the Correlations page

## Status

resolved

## Severity

high

## Scope

app

## Description

The  /correlations  index page provides no way to navigate to  /correlations/goals . There is no button, link, or menu item referencing goal metrics configuration. Users cannot access the goal metric selection feature without knowing the direct URL. The brief's setup notes acknowledge this gap: "The  /correlations  index page ( CorrelationLive.Index ) does not currently contain a navigation link or button to  /correlations/goals ." This is a critical discoverability issue. The entire goal metrics feature is unreachable from the UI navigation. Reproduction: log in as any user, navigate to  /correlations  — no path to goal configuration exists.

## Source

QA Story 446 — `.code_my_spec/qa/446/result.md`

## Resolution

Added a 'Configure Goals' link with data-role='configure-goals' to the correlations index page header, placed between the mode toggle and the Run Now button. The link navigates to /correlations/goals. File changed: lib/metric_flow_web/live/correlation_live/index.ex. Verified with mix compile (clean) and MIX_ENV=test mix agent_test test/metric_flow_web/live/correlation_live/ (78 tests, 0 failures).
