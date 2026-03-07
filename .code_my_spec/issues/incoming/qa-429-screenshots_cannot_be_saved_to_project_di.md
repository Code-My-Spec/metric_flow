# Screenshots cannot be saved to project directory by QA agent

## Severity

low

## Scope

qa

## Description

The vibium MCP browser tool saves screenshots to  /Users/johndavenport/Pictures/Vibium/  regardless of the  filename  parameter path provided. When the QA agent attempts to copy the files from  ~/Pictures/Vibium/  into the project's  .code_my_spec/qa/429/screenshots/  directory using a shell command, the sandbox denies the operation because  ~/Pictures/Vibium/  is outside the sandbox write allowlist. The screenshots exist at their Vibium location but cannot be automatically moved into the project. A manual copy or a sandbox allowlist update for  ~/Pictures/Vibium/  would resolve this. Files to copy: /Users/johndavenport/Pictures/Vibium/b1-acceptance-page-logged-in.png /Users/johndavenport/Pictures/Vibium/b2-acceptance-page-unauthenticated.png /Users/johndavenport/Pictures/Vibium/b3-login-with-return-to.png /Users/johndavenport/Pictures/Vibium/b4-register-with-return-to.png /Users/johndavenport/Pictures/Vibium/b5-after-accepting-accounts-page.png /Users/johndavenport/Pictures/Vibium/b6-accounts-list-with-client-account.png /Users/johndavenport/Pictures/Vibium/b7-already-accepted-token-redirect.png /Users/johndavenport/Pictures/Vibium/b7-nonexistent-token-redirect.png /Users/johndavenport/Pictures/Vibium/b8-decline-invitation.png Destination:  /Users/johndavenport/Documents/github/metric_flow/.code_my_spec/qa/429/screenshots/

## Source

QA Story 429 — `.code_my_spec/qa/429/result.md`
