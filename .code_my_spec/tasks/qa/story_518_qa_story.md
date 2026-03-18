# QA Story 518: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 518. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Sync QuickBooks Account Transaction Data

As a client user, I want my QuickBooks income account data synced daily so that credit transactions (money coming into the business) are available as a metric for correlation analysis against my marketing activity.

### Acceptance Criteria

- System connects to QuickBooks via the OAuth token established in the Connect Financial Platform via OAuth story (435) — no separate auth flow
- Data is fetched per income account selected by the user during OAuth connection setup; multiple selected accounts are each synced independently
- For each account, the system fetches debit and credit transaction totals aggregated by day using the QuickBooks Reports or Transactions API
- Credits (money in) are stored as the primary metric — this represents revenue flowing into the account and is the target variable for correlation analysis
- Debits (money out) are also stored as a separate metric so spend patterns can optionally be correlated as well
- Each metric is stored as a daily aggregate value — individual transactions are not stored, only the sum of credits and sum of debits per account per day
- Metric keys are: QUICKBOOKS_ACCOUNT_DAILY_CREDITS and QUICKBOOKS_ACCOUNT_DAILY_DEBITS
- platformExternalId is set to the QuickBooks account ID; externalLocationId is null (financial data has no location concept)
- On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date
- Days with no transactions are stored as zero-value records rather than gaps, to preserve continuity for correlation calculations
- Sync failures are logged with full error context including accountId, customerName, and dateRange and surfaced in Sync Status and History

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4828_system_connects_to_quickbooks_via_the_oauth_token_established_in_the_connect_financial_platform_via_oauth_story_435_no_separate_auth_flow_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4829_data_is_fetched_per_income_account_selected_by_the_user_during_oauth_connection_setup_multiple_selected_accounts_are_each_synced_independently_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4830_for_each_account_the_system_fetches_debit_and_credit_transaction_totals_aggregated_by_day_using_the_quickbooks_reports_or_transactions_api_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4831_credits_money_in_are_stored_as_the_primary_metric_this_represents_revenue_flowing_into_the_account_and_is_the_target_variable_for_correlation_analysis_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4832_debits_money_out_are_also_stored_as_a_separate_metric_so_spend_patterns_can_optionally_be_correlated_as_well_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4833_each_metric_is_stored_as_a_daily_aggregate_value_individual_transactions_are_not_stored_only_the_sum_of_credits_and_sum_of_debits_per_account_per_day_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4834_metric_keys_are_quickbooks_account_daily_credits_and_quickbooks_account_daily_debits_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4836_on_first_sync_system_backfills_up_to_548_days_of_historical_data_subsequent_syncs_fetch_from_the_day_after_the_last_stored_metric_date_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4837_days_with_no_transactions_are_stored_as_zero-value_records_rather_than_gaps_to_preserve_continuity_for_correlation_calculations_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/518_sync_quickbooks_account_transaction_data/criterion_4838_sync_failures_are_logged_with_full_error_context_including_accountid_customername_and_daterange_and_surfaced_in_sync_status_and_history_spex.exs`

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
7. Write the brief to `.code_my_spec/qa/518/brief.md` following the format below

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

