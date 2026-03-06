<!-- cms:task type="QaStory" component="431" -->

# QA Story 431: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 431. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Agency Views and Manages Client Accounts

As an agency user, I want to easily switch between client accounts I have access to so that I can efficiently manage multiple clients.

### Acceptance Criteria

- Agency sees list of all client accounts they have access to
- Each client listing shows access level and origination status
- Agency can switch between client accounts via account switcher
- Current client context is clearly displayed in navigation
- Agency with read-only access can only view reports and dashboards
- Agency with account manager access can modify reports and integrations but not delete account or manage users
- Agency with admin access can do everything except delete the account
- Agency cannot see other users who have access to the client account unless they have admin access
- If agency originated the client account, they see Originator badge

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3991_agency_sees_list_of_all_client_accounts_they_have_access_to_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3992_each_client_listing_shows_access_level_and_origination_status_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3993_agency_can_switch_between_client_accounts_via_account_switcher_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3994_current_client_context_is_clearly_displayed_in_navigation_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3995_agency_with_read-only_access_can_only_view_reports_and_dashboards_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3996_agency_with_account_manager_access_can_modify_reports_and_integrations_but_not_delete_account_or_manage_users_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3997_agency_with_admin_access_can_do_everything_except_delete_the_account_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3998_agency_cannot_see_other_users_who_have_access_to_the_client_account_unless_they_have_admin_access_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/431_agency_views_and_manages_client_accounts/criterion_3999_if_agency_originated_the_client_account_they_see_originator_badge_spex.exs`

## Linked Component: Index

This story is implemented by `MetricFlowWeb.AccountLive.Index` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/account_live/index.spec.md`
- Tests: `test/metric_flow_web/live/account_live/index_test.exs`
- Source: `lib/metric_flow_web/live/account_live/index.ex`

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
7. Write the brief to `.code_my_spec/qa/431/brief.md` following the format below

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

