<!-- cms:task type="QaStory" component="438" -->

# QA Story 438: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 438. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Manual Sync Trigger (Admin)

As an admin user, I want to manually trigger a data sync so that I can debug integration issues or get fresh data on demand.

### Acceptance Criteria

- Admin users see Sync Now button in integration settings
- Clicking sync triggers immediate data pull for that integration
- UI shows sync in progress with loading indicator
- Upon completion, user sees success message with timestamp and records synced
- If sync fails, error details are displayed
- Manual sync does not interfere with automated daily sync schedule

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4050_admin_users_see_sync_now_button_in_integration_settings_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4051_clicking_sync_triggers_immediate_data_pull_for_that_integration_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4052_ui_shows_sync_in_progress_with_loading_indicator_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4053_upon_completion_user_sees_success_message_with_timestamp_and_records_synced_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4054_if_sync_fails_error_details_are_displayed_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/438_manual_sync_trigger_admin/criterion_4055_manual_sync_does_not_interfere_with_automated_daily_sync_schedule_spex.exs`

## Linked Component: Index

This story is implemented by `MetricFlowWeb.IntegrationLive.Index` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/integration_live/index.spec.md`
- Source: `lib/metric_flow_web/live/integration_live/index.ex`
- Tests: `test/metric_flow_web/live/integration_live/index_test.exs`

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
7. Write the brief to `.code_my_spec/qa/438/brief.md` following the format below

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

