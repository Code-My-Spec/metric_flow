# QA environment requires server restart to pick up new module code

## Severity

medium

## Scope

qa

## Description

The running Phoenix development server does not automatically pick up module attribute ( @canonical_platforms )
changes via hot reload. The beam file on disk is compiled from the updated source, but the in-memory
module in the running BEAM still uses the old  build_platform_list/0  logic. The QA seed instructions (brief.md) assumed the server is running the current source. The brief should
include a note that the server must be restarted ( mix phx.server ) after significant source changes
before executing browser-based tests. Integration tests that depend on  @canonical_platforms  will fail
until the server is restarted. Steps to reproduce: Modify a module attribute in a LiveView, recompile (e.g., via  mix compile ), then
navigate to the LiveView in the browser without restarting the server. The module attribute value from
before the change is still used.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Triage Notes

Accepted — valid QA infrastructure issue. The QA brief should include a step to restart the Phoenix server before browser-based testing to ensure the running BEAM has the latest compiled modules.

## Resolution

Added a note to the QA plan (`plan.md`) in the Notes section instructing QA agents to restart the Phoenix server before browser-based testing. This ensures the running BEAM loads the latest compiled modules, preventing stale module attribute issues.

**Files changed:**
- `.code_my_spec/qa/plan.md`

**Verification:** Documentation-only change; no code tests needed.
