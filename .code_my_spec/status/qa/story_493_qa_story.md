<!-- cms:task type="QaStory" component="493" -->

# QA Story 493: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 493. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Cross-Platform Metric Normalization and Mapping

As a client user, I want the system to recognize that equivalent metrics from different platforms represent the same concept (e.g., a Google Ads click is the same as a Facebook Ads click), so that I can accurately compare and aggregate the same metric across platforms without manual reconciliation.

### Acceptance Criteria

- System maintains a canonical metric taxonomy (e.g., 'clicks', 'spend', 'impressions', 'conversions') that platform-specific metrics map to
- Each platform integration defines mappings from its native metric names to canonical metrics (e.g., Google Ads 'Clicks' and Facebook Ads 'Link Clicks' both map to canonical 'clicks')
- When a platform metric does not have a direct equivalent in the canonical taxonomy, it is stored as a platform-specific metric and clearly labeled as such
- Users can view which platform metrics are mapped to which canonical metrics
- Mapped metrics can be aggregated across platforms in dashboards and reports using canonical names
- Mapped metrics can be compared side-by-side across platforms (e.g., Google Ads clicks vs Facebook Ads clicks on the same chart)
- Metric mappings account for known semantic differences (e.g., different attribution windows or counting methods) and surface these as warnings or footnotes when comparing
- New platform integrations can define their metric mappings without requiring changes to existing canonical definitions
- Derived metrics (e.g., CPC) that reference canonical component metrics automatically work across platforms once their components are mapped

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4602_system_maintains_a_canonical_metric_taxonomy_eg_clicks_spend_impressions_conversions_that_platform-specific_metrics_map_to_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4603_each_platform_integration_defines_mappings_from_its_native_metric_names_to_canonical_metrics_eg_google_ads_clicks_and_facebook_ads_link_clicks_both_map_to_canonical_clicks_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4604_when_a_platform_metric_does_not_have_a_direct_equivalent_in_the_canonical_taxonomy_it_is_stored_as_a_platform-specific_metric_and_clearly_labeled_as_such_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4605_users_can_view_which_platform_metrics_are_mapped_to_which_canonical_metrics_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4606_mapped_metrics_can_be_aggregated_across_platforms_in_dashboards_and_reports_using_canonical_names_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4607_mapped_metrics_can_be_compared_side-by-side_across_platforms_eg_google_ads_clicks_vs_facebook_ads_clicks_on_the_same_chart_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4608_metric_mappings_account_for_known_semantic_differences_eg_different_attribution_windows_or_counting_methods_and_surface_these_as_warnings_or_footnotes_when_comparing_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4609_new_platform_integrations_can_define_their_metric_mappings_without_requiring_changes_to_existing_canonical_definitions_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/493_cross-platform_metric_normalization_and_mapping/criterion_4610_derived_metrics_eg_cpc_that_reference_canonical_component_metrics_automatically_work_across_platforms_once_their_components_are_mapped_spex.exs`

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
7. Write the brief to `.code_my_spec/qa/493/brief.md` following the format below

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

