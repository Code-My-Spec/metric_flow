<!-- cms:task type="QaStory" component="451" -->

# QA Story 451: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 451. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: AI Chat for Data Exploration

As a client user, I want to chat with AI about my data so that I can ask questions and get insights in natural language.

### Acceptance Criteria

- User can open AI chat from any report or visualization
- Chat context includes relevant data from current view
- User can ask questions like Why did my revenue drop last week
- AI has access to all metrics and correlation data to answer
- AI can suggest visualizations or reports based on questions
- Chat history is saved per user
- User can share chat insights with team members

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4138_user_can_open_ai_chat_from_any_report_or_visualization_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4139_chat_context_includes_relevant_data_from_current_view_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4140_user_can_ask_questions_like_why_did_my_revenue_drop_last_week_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4141_ai_has_access_to_all_metrics_and_correlation_data_to_answer_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4142_ai_can_suggest_visualizations_or_reports_based_on_questions_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4143_chat_history_is_saved_per_user_spex.exs`
- `/Users/johndavenport/Documents/github/metric_flow/test/spex/451_ai_chat_for_data_exploration/criterion_4144_user_can_share_chat_insights_with_team_members_spex.exs`

## Linked Component: Chat

This story is implemented by `MetricFlowWeb.AiLive.Chat` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/ai_live/chat.spec.md`
- Tests: `test/metric_flow_web/live/ai_live/chat_test.exs`
- Source: `lib/metric_flow_web/live/ai_live/chat.ex`

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
7. Write the brief to `.code_my_spec/qa/451/brief.md` following the format below

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

