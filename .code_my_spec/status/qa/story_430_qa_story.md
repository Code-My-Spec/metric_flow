<!-- cms:task type="QaStory" component="430" -->

# QA Story 430: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 430. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Manage User Access Permissions

As a client account owner, I want to manage which users have access to my account so that I can control who can view and modify my data.

### Acceptance Criteria

- Client can view list of all users with access to their account
- List shows user or agency name, access level, date granted, and whether they are account originator
- Client can modify a user access level to upgrade or downgrade permissions
- Client can revoke a user access at any time
- When access is revoked, user immediately loses ability to view client data
- System logs all permission changes with timestamp and user who made change
- Account originator cannot have their access revoked, only ownership can be transferred

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3984_client_can_view_list_of_all_users_with_access_to_their_account_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3985_list_shows_user_or_agency_name_access_level_date_granted_and_whether_they_are_account_originator_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3986_client_can_modify_a_user_access_level_to_upgrade_or_downgrade_permissions_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3987_client_can_revoke_a_user_access_at_any_time_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3988_when_access_is_revoked_user_immediately_loses_ability_to_view_client_data_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3989_system_logs_all_permission_changes_with_timestamp_and_user_who_made_change_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/430_manage_user_access_permissions/criterion_3990_account_originator_cannot_have_their_access_revoked_only_ownership_can_be_transferred_spex.exs`

## Linked Component: Members

This story is implemented by `MetricFlowWeb.AccountLive.Members` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/account_live/members.spec.md`
- Source: `lib/metric_flow_web/live/account_live/members.ex`
- Tests: `test/metric_flow_web/live/account_live/members_test.exs`

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
7. Write the brief to `.code_my_spec/qa/430/brief.md` following the format below

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

