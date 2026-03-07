<!-- cms:task type="QaStory" component="441" -->

# QA Story 441: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 441. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: View All Metrics Dashboard

As a client user, I want to see all my metrics from all platforms in one unified view so that I can understand my complete marketing and financial picture.

### Acceptance Criteria

- User can access All Metrics dashboard showing data from all connected platforms
- Dashboard displays both marketing metrics and financial metrics with no distinction
- User can filter by platform, date range, or metric type
- User can select date range: last 7 days, 30 days, 90 days, all time, custom
- Date ranges default to last X days from yesterday to avoid incomplete current day
- Dashboard updates dynamically when filters change
- If no integrations connected, dashboard shows onboarding prompts
- All visualizations use Vega-Lite

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4068_user_can_access_all_metrics_dashboard_showing_data_from_all_connected_platforms_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4069_dashboard_displays_both_marketing_metrics_and_financial_metrics_with_no_distinction_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4070_user_can_filter_by_platform_date_range_or_metric_type_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4071_user_can_select_date_range_last_7_days_30_days_90_days_all_time_custom_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4072_date_ranges_default_to_last_x_days_from_yesterday_to_avoid_incomplete_current_day_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4073_dashboard_updates_dynamically_when_filters_change_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4074_if_no_integrations_connected_dashboard_shows_onboarding_prompts_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/441_view_all_metrics_dashboard/criterion_4075_all_visualizations_use_vega-lite_spex.exs`

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
7. Write the brief to `.code_my_spec/qa/441/brief.md` following the format below

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

