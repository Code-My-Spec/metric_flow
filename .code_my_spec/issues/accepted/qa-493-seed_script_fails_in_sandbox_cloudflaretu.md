# Seed script fails in sandbox — CloudflareTunnel write permission error

## Severity

medium

## Scope

qa

## Description

Running  mix run priv/repo/qa_seeds.exs  inside the Claude Code sandbox fails with: (File.Error) could not write to file "/Users/johndavenport/.cloudflared/config.yml": not owner The  ClientUtils.CloudflareTunnel  supervisor attempts to write to  ~/.cloudflared/config.yml  during application startup, which the sandbox blocks. The seed script could not be run without disabling the sandbox ( dangerouslyDisableSandbox: true ). This affects all seed script execution and any  mix run  invocations inside the sandbox. The QA plan should document that seed scripts require running outside the sandbox or with sandbox restrictions lifted for the cloudflared path.

## Source

QA Story 493 — `.code_my_spec/qa/493/result.md`

## Resolution

Documented the sandbox constraint in the QA plan. The `mix run` section now includes a note that seed scripts must run with `dangerouslyDisableSandbox: true` due to the CloudflareTunnel supervisor writing to `~/.cloudflared/config.yml` during application startup.

Files changed:
- `.code_my_spec/qa/plan.md` — added sandbox note to the `mix run` section

Verified: QA plan updated, no code changes needed.
