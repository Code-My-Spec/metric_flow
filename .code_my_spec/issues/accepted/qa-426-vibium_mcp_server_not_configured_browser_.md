# vibium MCP server not configured — browser scenarios cannot execute

## Severity

high

## Scope

qa

## Description

The vibium MCP server (`mcp__vibium__browser_*` tools) is not available to QA
subagents. Both QA attempts for Story 426 (2026-03-05 and 2026-03-06) confirmed
that all `mcp__vibium__browser_*` tool calls return "No such tool available."

The root cause: the QA agent definition (`CodeMySpec/agents/qa.md`) does not
include `mcpServers: vibium` in its frontmatter, so the subagent cannot access
the vibium MCP server even though it is configured at the user level in
`~/.claude.json`.

As a result, all browser-based scenarios (1 and 3-11) cannot be executed and no
screenshots can be captured. The QA brief and plan both require vibium for all
LiveView UI testing.

Functional behavior was verified via `mix test` (21 unit tests, all pass) and
`mix spex` (8 BDD spex, all pass). However, the visual UI layer — role badge
rendering, form visibility toggling, flash messages, and the rendered HTML of the
members page in a real browser — was not verified.

## Resolution

Added `mcpServers: vibium` to the QA agent frontmatter in
`CodeMySpec/agents/qa.md`. This tells the subagent to inherit the vibium MCP
server that is already configured at the user level.

### Files Changed

- `CodeMySpec/agents/qa.md` — added `mcpServers: vibium` to YAML frontmatter

### Verification

The fix is a configuration change to the agent definition. Verification requires
re-running a QA story that uses vibium browser tools (e.g., Story 426) after
restarting Claude Code to pick up the updated agent definition.

## Source

QA Story 426 — `.code_my_spec/qa/426/result.md`
Merged from: `qa-426-vibium_mcp_server_unavailable_browser_sce.md` (duplicate)
