# Seeds cannot be re-run while Phoenix server is running (role drift between QA sessions)

## Status

resolved

## Severity

medium

## Scope

qa

## Description

mix run priv/repo/qa_seeds.exs  fails when the Phoenix server is running because the Cloudflare tunnel GenServer conflicts with the application startup. This is documented in the QA plan, but the consequence for Story 430 is significant: role changes made during a QA session persist to the next session. In this run,  qa-member@example.com  started as  owner  in "QA Test Account" (from a prior role-change test) rather than the expected  read_only . This caused Scenario 3 (invite flow) to be only partially testable and forced Scenario 6 to use a workaround. The QA plan notes an alternative invocation using  --no-start , but the alternative also requires the application modules to be started manually in the correct order. A  MIX_ENV -gated reset endpoint or a Wallaby/ExUnit sandbox reset would resolve this for live-server QA sessions.

## Source

QA Story 430 — `.code_my_spec/qa/430/result.md`

## Resolution

Disabled Cloudflare tunnel by default in config/dev.exs (enabled: false). Added enabled check in application.ex so the tunnel GenServer only starts when enabled: true. Seeds can now run via mix run while the Phoenix server is up.
