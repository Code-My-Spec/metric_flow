# BDD spex reference :owner_with_integrations given not implemented

## Status

accepted

## Severity

low

## Scope

qa

## Description

All six BDD spec files in  test/spex/439_sync_status_and_history/  reference a shared given
 :owner_with_integrations  (e.g.  given_ :owner_with_integrations ) which is not defined in
 test/support/shared_givens.ex . That file only defines  :user_registered_with_password ,
 :user_logged_in_as_owner , and  :second_user_registered . Running  mix spex  on the story 439
specs will fail at the given step resolution before any assertions are reached. The sync history page itself does not require integrations to be present to display the schedule
or empty state — the given name implies integration data but the specs only test the LiveView
message-handling path ( :sync_completed  and  :sync_failed  messages sent directly to the LiveView
pid), not any integration-specific UI. The missing given should be added to  shared_givens.ex 
as an alias or equivalent of  :user_logged_in_as_owner  with an optional integration fixture.

## Source

QA Story 439 — `.code_my_spec/qa/439/result.md`
