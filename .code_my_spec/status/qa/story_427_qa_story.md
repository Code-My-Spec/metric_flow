<!-- cms:task type="QaStory" component="427" -->

# QA Story 427: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 427. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Agency Team Auto-Enrollment

As an agency account owner, I want to automatically add team members from my organization so that I do not have to manually invite each employee.

### Acceptance Criteria

- Agency can configure domain-based auto-enrollment for their email domain
- Users who register with matching email domain are automatically added to agency account
- Auto-enrolled users get default access level set by agency admin
- Agency admin can view and manage all auto-enrolled team members
- Agency admin can disable auto-enrollment if desired
- Team members automatically inherit access to all client accounts the agency manages

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3963_agency_can_configure_domain-based_auto-enrollment_for_their_email_domain_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3964_users_who_register_with_matching_email_domain_are_automatically_added_to_agency_account_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3965_auto-enrolled_users_get_default_access_level_set_by_agency_admin_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3966_agency_admin_can_view_and_manage_all_auto-enrolled_team_members_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3967_agency_admin_can_disable_auto-enrollment_if_desired_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/427_agency_team_auto-enrollment/criterion_3968_team_members_automatically_inherit_access_to_all_client_accounts_the_agency_manages_spex.exs`

## Linked Component: Settings

This story is implemented by `MetricFlowWeb.AgencyLive.Settings` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/agency_live/settings.spec.md`
- Source: `lib/metric_flow_web/live/agency_live/settings.ex`
- Tests: `test/metric_flow_web/live/agency_live/settings_test.exs`

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
7. Write the brief to `.code_my_spec/qa/427/brief.md` following the format below

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

