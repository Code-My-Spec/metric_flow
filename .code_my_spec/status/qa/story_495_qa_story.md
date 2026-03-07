<!-- cms:task type="QaStory" component="495" -->

# QA Story 495: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 495. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Correct Aggregation of Derived and Calculated Metrics

As a client user, I want calculated metrics like cost-per-click or conversion rate to be aggregated correctly when viewed across time periods or platforms, so that I see mathematically accurate numbers rather than misleading averages of averages.

### Acceptance Criteria

- System distinguishes between raw/additive metrics (e.g., clicks, spend, impressions) and derived/calculated metrics (e.g., CPC, CTR, conversion rate, ROAS)
- Derived metrics are defined by a formula referencing their component raw metrics (e.g., CPC = total spend / total clicks)
- When aggregating derived metrics across time periods (e.g., daily to weekly), system sums the component metrics first then calculates the derived value from the aggregated components
- When aggregating derived metrics across multiple platforms or ad accounts, system sums the component metrics first then calculates the derived value from the aggregated components
- System never averages a derived metric directly across rows - it always re-derives from aggregated components
- Derived metric definitions are stored as metadata and can be extended for new metric types
- If a component metric has missing data for a time period, the derived metric for that period reflects the gap rather than silently producing incorrect values
- Derived metrics display identically to raw metrics in dashboards and reports - the aggregation logic is transparent to the user

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4611_system_distinguishes_between_rawadditive_metrics_eg_clicks_spend_impressions_and_derivedcalculated_metrics_eg_cpc_ctr_conversion_rate_roas_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4612_derived_metrics_are_defined_by_a_formula_referencing_their_component_raw_metrics_eg_cpc_total_spend_total_clicks_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4613_when_aggregating_derived_metrics_across_time_periods_eg_daily_to_weekly_system_sums_the_component_metrics_first_then_calculates_the_derived_value_from_the_aggregated_components_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4614_when_aggregating_derived_metrics_across_multiple_platforms_or_ad_accounts_system_sums_the_component_metrics_first_then_calculates_the_derived_value_from_the_aggregated_components_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4615_system_never_averages_a_derived_metric_directly_across_rows_-_it_always_re-derives_from_aggregated_components_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4616_derived_metric_definitions_are_stored_as_metadata_and_can_be_extended_for_new_metric_types_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4617_if_a_component_metric_has_missing_data_for_a_time_period_the_derived_metric_for_that_period_reflects_the_gap_rather_than_silently_producing_incorrect_values_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4618_derived_metrics_display_identically_to_raw_metrics_in_dashboards_and_reports_-_the_aggregation_logic_is_transparent_to_the_user_spex.exs`

## Linked Component: Show

This story is implemented by `MetricFlowWeb.DashboardLive.Show` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/dashboard_live/show.spec.md`
- Tests: `test/metric_flow_web/live/dashboard_live/show_test.exs`
- Source: `lib/metric_flow_web/live/dashboard_live/show.ex`

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
7. Write the brief to `.code_my_spec/qa/495/brief.md` following the format below

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

