#!/usr/bin/env bash
# login.sh — DEPRECATED: Use vibium MCP tools instead.
#
# Browser automation is now handled via MCP tool calls, not CLI commands.
# See .code_my_spec/qa/plan.md for the auth workflow.
#
# Quick reference (MCP tool calls):
#   mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
#   mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
#   mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
#   mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
#   mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
#   mcp__vibium__browser_wait(selector: "body", timeout: 5000)

echo "DEPRECATED: Use vibium MCP tools for login. See .code_my_spec/qa/plan.md"
exit 1
