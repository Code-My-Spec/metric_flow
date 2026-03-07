<!-- cms:task type="QaStory" component="453" -->

# QA Story 453: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 453. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Agency White-label Configuration

As an agency account owner, I want to configure white-label branding for my agency so that clients see my brand when accessing reports.

### Acceptance Criteria

- Agency can upload custom logo (supports PNG, JPG, SVG)
- Agency can set custom color scheme (primary, secondary, accent colors)
- Agency can configure custom subdomain (e.g., reports.andersonthefish.com)
- Changes preview in real-time before saving
- Agency can reset to default branding
- White-label settings are stored at agency account level
- Custom subdomain requires DNS verification before activation
- No Anderson Analytics branding visible on white-labeled instances

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4152_agency_can_upload_custom_logo_supports_png_jpg_svg_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4153_agency_can_set_custom_color_scheme_primary_secondary_accent_colors_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4154_agency_can_configure_custom_subdomain_eg_reportsandersonthefishcom_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4155_changes_preview_in_real-time_before_saving_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4156_agency_can_reset_to_default_branding_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4157_white-label_settings_are_stored_at_agency_account_level_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4158_custom_subdomain_requires_dns_verification_before_activation_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/453_agency_white-label_configuration/criterion_4159_no_anderson_analytics_branding_visible_on_white-labeled_instances_spex.exs`

## Linked Component: Settings

This story is implemented by `MetricFlowWeb.AgencyLive.Settings` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/agency_live/settings.spec.md`
- Tests: `test/metric_flow_web/live/agency_live/settings_test.exs`
- Source: `lib/metric_flow_web/live/agency_live/settings.ex`

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
7. Write the brief to `.code_my_spec/qa/453/brief.md` following the format below

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

