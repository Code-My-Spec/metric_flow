# start-qa.sh does not source uat.env — AI key missing during QA runs

## Severity

medium

## Scope

qa

## Description

The QA start script  .code_my_spec/qa/scripts/start-qa.sh  runs seed scripts but does not source  uat.env  or set the  ANTHROPIC_API_KEY  environment variable. As a result, when the Phoenix server is started separately without the key, all AI streaming calls fail with a generic "The AI encountered an error" flash. The QA plan at  .code_my_spec/qa/plan.md  does not mention that the server must be started with  ANTHROPIC_API_KEY  set. This is a gap in the QA infrastructure documentation. Recommended fix: Add a note to  .code_my_spec/qa/plan.md  and to  start-qa.sh  that the server must be started with: source uat.env && mix phx.server or that  uat.env  must be exported into the shell before starting the server.

## Source

QA Story 451 — `.code_my_spec/qa/451/result.md`

## Resolution

Added `uat.env` sourcing to `start-qa.sh` (Step 0, before seed data). Uses `set -a`/`set +a` to auto-export all variables. Prints a warning if `uat.env` is not found. Also added a note to `.code_my_spec/qa/plan.md` documenting the API key requirement.

**Files changed:**
- `.code_my_spec/qa/scripts/start-qa.sh` — Added uat.env sourcing block
- `.code_my_spec/qa/plan.md` — Added note about API key requirement

**Verified:** Script syntax is valid; QA plan updated.
