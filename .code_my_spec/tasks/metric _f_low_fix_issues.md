# Fix Issues

You are fixing accepted QA issues at **medium+** severity.

## Goal

For each issue below:

1. **Understand the problem** — read the issue description and source QA result
2. **Fix the code** — use subagents (Agent tool) for the actual fix work. Group related issues
   into one subagent if they share a root cause. Each subagent should:
   - Read the relevant source files
   - Make the fix
   - Verify the fix works
3. **Add a `## Resolution` section** to each issue file describing what was done:
   - Summary of the fix
   - Files changed
   - How the fix was verified
4. **Run tests** after all fixes to verify nothing is broken: `mix test`

## Scope-Aware Fixing

Issues have a scope indicating what to fix:
- **app** — Fix application code (controllers, live views, schemas, etc.)
- **qa** — Fix QA infrastructure (seed scripts, auth scripts, QA plan, test tooling)
- **docs** — Fix documentation (specs, README, user stories)

Read the scope before fixing — a `qa` issue means the seeds or scripts need updating, not the app code.

## QA Results

Issue source references point to QA result files in `.code_my_spec/qa/`. Read those
files for additional context, reproduction steps, and screenshots.

## Unresolved Issues

## Scope: qa (1)

### `qa-436-google_ads_integration_seed_cannot_be_run.md`

**Source:** `.code_my_spec/qa/436/result.md`

- **Title:** google_ads integration seed cannot be run while server is active
- **Severity:** medium
- **Scope:** qa
- **Story:** 436

The brief instructs running a  mix run -e '...'  one-liner to create a google_ads integration with  selected_accounts  in  provider_metadata . This fails when the Phoenix server is already running because the Cloudflare tunnel GenServer conflicts with the  mix run  process attempting to start the application. The brief acknowledges this is a "one-off seed step" but does not provide an alternative for the server-running scenario. As a result, the selected_accounts scenario (Scenario 6) and the "Google Ads" platform name scenarios could not be tested with the intended seed data. Resolution options: (1) Add a  --no-start  compatible version of the seed using  Repo.start_link  and skipping Cloudflare, (2) Add the google_ads integration to  priv/repo/qa_seeds.exs  as an idempotent step, or (3) Use a Mix task that bypasses the full application startup.

## Directory

Accepted issues: `.code_my_spec/issues/accepted/`

Fix the issues, add resolution sections, and run tests to verify.
