# Vibium daemon stale socket blocks browser-based testing

## Severity

medium

## Scope

qa

## Disposition

Dismissed — this is a vibium tool bug (stale socket not cleaned up on crash), not something we can fix in our codebase. Workaround: `rm -f ~/Library/Caches/vibium/vibium.sock` before starting the daemon.

## Description

The vibium daemon socket file at  ~/Library/Caches/vibium/vibium.sock  was stale (left
from a previous session). The daemon reported "not running" via  vibium daemon status  but
the socket file existed, causing  vibium daemon start --headless  to fail with "address
already in use".

## Source

QA Story 425 — `.code_my_spec/qa/425/result.md`
