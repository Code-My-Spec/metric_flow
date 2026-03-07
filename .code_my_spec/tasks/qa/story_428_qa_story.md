<!-- cms:task type="QaStory" component="428" -->

# QA Story 428: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 428. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Client Invites Agency or Individual User Access

As a client account owner, I want to invite agencies or individual users to access my account so that they can help manage my marketing data and reporting.

### Acceptance Criteria

- Client can send email invitation to any email address (agency or individual)
- Invitation email contains secure link with expiration time of 7 days
- Invitee receives invitation in their email inbox
- Invitation includes client account name and access level being granted
- Client can specify access level in invitation: read-only, account manager, or admin
- Invitation link is single-use and invalidated after acceptance or expiration
- Client can view pending invitations and cancel them before acceptance
- Client can invite multiple agencies or users with different access levels

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3969_client_can_send_email_invitation_to_any_email_address_agency_or_individual_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3970_invitation_email_contains_secure_link_with_expiration_time_of_7_days_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3971_invitee_receives_invitation_in_their_email_inbox_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3972_invitation_includes_client_account_name_and_access_level_being_granted_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3973_client_can_specify_access_level_in_invitation_read-only_account_manager_or_admin_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3974_invitation_link_is_single-use_and_invalidated_after_acceptance_or_expiration_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3975_client_can_view_pending_invitations_and_cancel_them_before_acceptance_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/428_client_invites_agency_or_individual_user_access/criterion_3976_client_can_invite_multiple_agencies_or_users_with_different_access_levels_spex.exs`

## Linked Component: Send

This story is implemented by `MetricFlowWeb.InvitationLive.Send` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/invitation_live/send.spec.md`
- Tests: `test/metric_flow_web/live/invitation_live/send_test.exs`
- Source: `lib/metric_flow_web/live/invitation_live/send.ex`

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
7. Write the brief to `.code_my_spec/qa/428/brief.md` following the format below

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

