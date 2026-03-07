<!-- cms:task type="QaStory" component="437" -->

# QA Story 437: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 437. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Automated Daily Data Sync

As a system, I want to automatically sync data from all connected platforms daily so that user data stays fresh without manual intervention.

### Acceptance Criteria

- System runs daily sync job at scheduled time (e.g., 2 AM UTC)
- Sync pulls new data from all active integrations for all accounts
- On first sync after connection, system backfills all available historical data from platform
- Financial data (debits and credits) is stored as metrics alongside marketing metrics
- Sync retrieves metrics, review data, and financial data for each day
- OAuth tokens are automatically refreshed when needed
- Failed syncs are automatically retried up to 3 times with exponential backoff
- Sync errors are logged with details for debugging
- Default date ranges exclude today to avoid showing zero for incomplete day

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4041_system_runs_daily_sync_job_at_scheduled_time_eg_2_am_utc_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4042_sync_pulls_new_data_from_all_active_integrations_for_all_accounts_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4043_on_first_sync_after_connection_system_backfills_all_available_historical_data_from_platform_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4044_financial_data_debits_and_credits_is_stored_as_metrics_alongside_marketing_metrics_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4045_sync_retrieves_metrics_review_data_and_financial_data_for_each_day_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4046_oauth_tokens_are_automatically_refreshed_when_needed_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4047_failed_syncs_are_automatically_retried_up_to_3_times_with_exponential_backoff_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4048_sync_errors_are_logged_with_details_for_debugging_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/437_automated_daily_data_sync/criterion_4049_default_date_ranges_exclude_today_to_avoid_showing_zero_for_incomplete_day_spex.exs`

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
7. Write the brief to `.code_my_spec/qa/437/brief.md` following the format below

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

