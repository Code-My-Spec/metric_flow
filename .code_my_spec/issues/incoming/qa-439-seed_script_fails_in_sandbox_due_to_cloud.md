# seed script fails in sandbox due to Cloudflare tunnel write permission

## Status

dismissed

## Severity

low

## Scope

qa

## Description

Running  mix run priv/repo/qa_seeds.exs  fails in the default Claude Code sandbox because the
 ClientUtils.CloudflareTunnel  supervision tree child attempts to write to
 /Users/johndavenport/.cloudflared/config.yml  which is not writable in the sandbox environment.
The error is: (File.Error) could not write to file "/Users/johndavenport/.cloudflared/config.yml": not owner This affects all  mix run  commands including seed scripts and the story-specific seed script
used in this QA session. The workaround is to run with  dangerouslyDisableSandbox: true .
This is a QA infrastructure issue — the seed scripts themselves work correctly once the
sandbox restriction is bypassed.

## Source

QA Story 439 — `.code_my_spec/qa/439/result.md`
