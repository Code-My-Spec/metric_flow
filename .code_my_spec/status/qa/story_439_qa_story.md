<!-- cms:task type="QaStory" component="439" -->

# QA Story 439: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 439. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Sync Status and History

As an admin user, I want to view sync history and status for each integration so that I can diagnose issues and understand data freshness.

### Acceptance Criteria

- Each integration shows last successful sync timestamp
- Each integration shows next scheduled sync time
- User can view detailed sync history (last 30 syncs minimum)
- Sync history shows: timestamp, status (success or failure), records synced, and any error messages
- Failed syncs are highlighted with error details
- User can filter sync history by status (all, success, failed)

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4056_each_integration_shows_last_successful_sync_timestamp_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4057_each_integration_shows_next_scheduled_sync_time_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4058_user_can_view_detailed_sync_history_last_30_syncs_minimum_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4059_sync_history_shows_timestamp_status_success_or_failure_records_synced_and_any_error_messages_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4060_failed_syncs_are_highlighted_with_error_details_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/439_sync_status_and_history/criterion_4061_user_can_filter_sync_history_by_status_all_success_failed_spex.exs`

## Linked Component: SyncHistory

This story is implemented by `MetricFlowWeb.IntegrationLive.SyncHistory` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/integration_live/sync_history.spec.md`
- Tests: `test/metric_flow_web/live/integration_live/sync_history_test.exs`
- Source: `lib/metric_flow_web/live/integration_live/sync_history.ex`

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
7. Write the brief to `.code_my_spec/qa/439/brief.md` following the format below

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

