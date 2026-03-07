<!-- cms:task type="QaStory" component="447" -->

# QA Story 447: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 447. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Automated Correlation Analysis

As a client user, I want to see which marketing metrics correlate most with my goal metrics so that I can focus on activities that drive business results.

### Acceptance Criteria

- System automatically calculates correlations between all metrics and selected goal metric(s)
- Correlations are calculated daily after data sync completes
- System tests multiple time lags (0-30 days) for each metric to automatically find optimal lag
- System selects lag with highest absolute correlation value for each metric
- Correlation calculations use daily aggregated data
- Only correlations meeting minimum data threshold are calculated (e.g., 30+ days of data)
- Correlation runs against ALL metrics (financial and marketing treated the same)

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4108_system_automatically_calculates_correlations_between_all_metrics_and_selected_goal_metrics_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4109_correlations_are_calculated_daily_after_data_sync_completes_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4110_system_tests_multiple_time_lags_0-30_days_for_each_metric_to_automatically_find_optimal_lag_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4111_system_selects_lag_with_highest_absolute_correlation_value_for_each_metric_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4112_correlation_calculations_use_daily_aggregated_data_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4113_only_correlations_meeting_minimum_data_threshold_are_calculated_eg_30_days_of_data_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/447_automated_correlation_analysis/criterion_4114_correlation_runs_against_all_metrics_financial_and_marketing_treated_the_same_spex.exs`

## Linked Component: Index

This story is implemented by `MetricFlowWeb.CorrelationLive.Index` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/correlation_live/index.spec.md`
- Tests: `test/metric_flow_web/live/correlation_live/index_test.exs`
- Source: `lib/metric_flow_web/live/correlation_live/index.ex`

## Available Scripts

These scripts handle auth and seeds — reference them in the brief instead
of writing inline commands:

- `/Users/johndavenport/Documents/github/metric_flow/.code_my_spec/qa/scripts/login.sh`
- `/Users/johndavenport/Documents/github/metric_flow/.code_my_spec/qa/scripts/logout.sh`
- `/Users/johndavenport/Documents/github/metric_flow/.code_my_spec/qa/scripts/start-qa.sh`

## Instructions

1. Read `.code_my_spec/framework/qa-tooling.md` for testing tool patterns and `.code_my_spec/framework/qa-tooling/` for tool-specific cheat sheets
2. Read `.code_my_spec/qa/plan.md` for app overview, tools, auth, and seed strategy
3. Run seed scripts to verify setup works for this story
4. If this story needs additional seeds, scripts, or plan updates, make them now
5. Read the BDD spec files listed above (they contain selectors, test data, and assertions)
6. If a linked component is listed above, read its source and spec to understand the feature
7. Write the brief to `.code_my_spec/qa/447/brief.md` following the format below

Stop the session after writing the brief.

## Brief Format

# Qa Story Brief

Per-story QA testing brief. Written by the QA planner after reading the story's prompt file and the QA plan. Gives the tester exact instructions — tool, auth, seeds, what to test.

## Required Sections

### Tool

Format:
- Use H2 heading
- Single line: tool name (web, curl, or script path)

Content:
- Which tool to use for this story's testing
- `web` for LiveView pages, `curl` or script path for controller/API routes


### Auth

Format:
- Use H2 heading
- Exact commands or instructions the tester copies verbatim

Content:
- Login URL, credentials, headers — whatever the tool needs
- Reference auth scripts from the QA plan if applicable
- Tester should not need to figure out auth on their own


### Seeds

Format:
- Use H2 heading
- Exact commands to run

Content:
- Seed script references (`mix run priv/repo/qa_seeds.exs`)
- Any story-specific seed commands beyond the base seeds
- Entity IDs or values the tester will need


### What To Test

Format:
- Use H2 heading
- Bullet list of specific test scenarios

Content:
- Specific URLs to visit
- Interactions to perform (click, fill form, submit)
- Expected outcomes (what the tester should see)
- Map to acceptance criteria from the story


### Result Path

Format:
- Use H2 heading
- Single line: file path

Content:
- Where the tester writes the result document


## Optional Sections

### Setup Notes

Format:
- Use H2 heading
- Free-form paragraphs

Content:
- Additional context, prerequisites, known issues

