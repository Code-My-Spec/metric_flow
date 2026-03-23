# QA Story 515: Write the Brief

**App URL:** Run `mix run -e 'IO.puts(MetricFlowWeb.Endpoint.url())'` to get the app URL.

Write a testing brief for story 515. The brief tells the tester exactly
what to do — which tools, how to authenticate, what seeds to run, and what to test.

**Available tools:** MCP browser tools (browser automation for UI/LiveView pages), `curl` (API
endpoint testing with API key auth), and shell scripts in `.code_my_spec/qa/scripts/`.
See `.code_my_spec/framework/qa-tooling.md` for when to use each tool.

## Story: Calculate Rolling Review Metrics from Review Table

As a system, I want to derive daily rolling review metrics from the Review table regardless of source platform, so that review performance can be correlated with marketing and financial data across any platform that produces reviews.

### Acceptance Criteria

- Metric calculation is platform-agnostic — it operates on the Review table directly and produces identical output whether reviews came from Google Business Profile, Yelp, Trustpilot, or any future review source
- For each location, the system calculates three metrics per day across the full date range from earliest to latest review date: dailyReviewCount (reviews with reviewDate on that exact day), totalReviews (rolling count of all reviews up to end of that day), averageRating (rolling average of all ratings up to end of that day)
- All three metrics are persisted as Metric rows keyed as: BUSINESS_REVIEW_DAILY_COUNT, BUSINESS_REVIEW_TOTAL_COUNT, BUSINESS_REVIEW_AVERAGE_RATING
- Metrics are stored at location level (externalLocationId populated) — one row per metric key per day per location
- If no reviews exist for a location, no metrics are written and a warning is logged
- Calculation is triggered after any review sync completes — it is not coupled to a specific platform sync; any sync that writes to the Review table should trigger recalculation for the affected locations
- Existing metric rows for BUSINESS_REVIEW_* keys are deleted and recalculated on each run (rebuild model) until upsert-based incremental calculation is implemented
- averageRating values are stored as floats rounded to 2 decimal places

### BDD Spec Files

- `/Users/johndavenport/Documents/github/metric_flow/test/spex/515_calculate_rolling_review_metrics_from_review_table/criterion_4798_metric_calculation_is_platform-agnostic_it_operates_on_the_review_table_directly_and_produces_identical_output_whether_reviews_came_from_google_business_profile_yelp_trustpilot_or_any_future_review_source_spex.exs`

## Linked Component: Index

This story is implemented by `MetricFlowWeb.ReportLive.Index` (liveview).
Reading the source code and spec will help you understand what to test
and how the feature works.

- Spec: `.code_my_spec/spec/metric_flow_web/report_live/index.spec.md`
- Tests: `test/metric_flow_web/live/report_live/index_test.exs`
- Source: `lib/metric_flow_web/live/report_live/index.ex`

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
7. Write the brief to `.code_my_spec/qa/515/brief.md` following the format below

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

