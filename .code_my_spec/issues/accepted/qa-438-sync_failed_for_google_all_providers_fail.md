# "Sync failed for google: all_providers_failed" error message is not user-friendly

## Status

accepted

## Severity

low

## Scope

app

## Description

When a sync attempt fails because all data providers return errors, the LiveView broadcasts  {:sync_failed, %{provider: :google, reason: :all_providers_failed}} . The  handle_info/2  handler renders this as the error flash: "Sync failed for google: all_providers_failed". Two issues: The provider name is rendered as the raw atom string  "google"  rather than the display name "Google". The  format_error/1  helper in  SyncWorker  uses  Atom.to_string/1 , and the  handle_info  clause in  index.ex  uses  provider  directly rather than looking up the display name. "all_providers_failed" is an internal error atom, not a user-facing message. Users would not understand what this means. A clearer message would be: "Sync failed for Google. Please check your connection and try again." Reproduced by: logging in as  qa@example.com , navigating to  http://localhost:4070/integrations , clicking "Sync Now" on the Google card.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`
