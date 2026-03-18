# Fix Issues

You are fixing accepted QA issues at **medium+** severity.

## Tools

Use the following bash tools in `.code_my_spec/tools/issues/` to interact with issues:

- `.code_my_spec/tools/issues/get-issue <id>` — read full issue details
- `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` — mark as resolved with description of fix

## Goal

For each issue below:

1. **Understand the problem** — read the issue description and source QA result
2. **Fix the code** — use subagents (Agent tool) for the actual fix work. Group related issues
   into one subagent if they share a root cause. Each subagent should:
   - Read the relevant source files
   - Make the fix
   - Verify the fix works
3. **Resolve the issue** — run `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` with a summary of:
   - What was fixed
   - Files changed
   - How the fix was verified
4. **Run tests** after all fixes to verify nothing is broken: `mix test`

## Scope-Aware Fixing

Issues have a scope indicating what to fix:
- **app** — Fix application code (controllers, live views, schemas, etc.)
- **qa** — Fix QA infrastructure (seed scripts, auth scripts, QA plan, test tooling)
- **docs** — Fix documentation (specs, README, user stories)

Read the scope before fixing — a `qa` issue means the seeds or scripts need updating, not the app code.

## QA Context

- **QA plan:** `.code_my_spec/qa/plan.md` — server startup, seeds, auth strategy
- **QA results:** `.code_my_spec/qa/{story_id}/` — failed results, screenshots, briefs

Read the QA plan for how to start the server and run seeds if you need to verify fixes.
Read the failed result and screenshots for each issue's story to understand the reproduction.

## Unresolved Issues

## Scope: qa (1)

### `qa-517-spex_criterion_4819_and_4827_fail_to_load.md` (ID: eecb7ced-ce49-4c8d-a9d8-57368ea3fc6c)

**Source:** `.code_my_spec/qa/517/result.md`
**QA evidence:** `.code_my_spec/qa/517/`
- **Title:** Spex criterion 4819 and 4827 fail to load due to test name length exceeding 255 characters
- **Severity:** medium
- **Scope:** qa
- **Story:** 517

Two spex files in  test/spex/517_sync_google_business_profile_performance_metrics/  cannot be loaded by ExUnit because their computed test names exceed the 255-character limit: Criterion 4819: spex title is 258 chars — "The following metrics are fetched as daily time series: BUSINESS_IMPRESSIONS_DESKTOP_MAPS, BUSINESS_IMPRESSIONS_DESKTOP_SEARCH, BUSINESS_IMPRESSIONS_MOBILE_MAPS, BUSINESS_CONVERSATIONS, BUSINESS_DIRECTION_REQUESTS, CALL_CLICKS, WEBSITE_CLICKS, BUSINESS_BOOKINGS, BUSINESS_FOOD_ORDERS, BUSINESS_FOOD_MENU_CLICKS" Criterion 4827: spex title is 265 chars — "Google Business Profile performance integration is distinct from GMB Reviews — both use the same account and location config but call different APIs and store different data under different platformServiceType values ('mybusiness' vs 'mybusiness-reviews')" Error:  the computed name of a test must be shorter than 255 characters . Both files need their  spex "..."  title shortened while preserving the meaning.

## Directory

Accepted issues: `.code_my_spec/issues/accepted/`

Fix the issues, resolve them with the tool, and run tests to verify.
