# Vibium MCP browser tools unavailable — browser-based QA scenarios could not execute

## Severity

high

## Scope

qa

## Disposition

Dismissed as duplicate of `qa-426-vibium_mcp_server_not_configured_browser_.md` (accepted).

Same root cause: QA subagent cannot access vibium MCP tools. The accepted issue already has a resolution (added `mcpServers: vibium` to agent frontmatter).

Additional finding from Story 455 investigation: even with `mcpServers` configured, vibium MCP tools are **deferred tools** that must be loaded via `ToolSearch` before calling. The subagent called `mcp__vibium__browser_launch` directly without loading it first, producing "No such tool available." The QA agent instructions should include a `ToolSearch` step to load vibium tools before use.

## Source

QA Story 455 — `.code_my_spec/qa/455/result.md`
