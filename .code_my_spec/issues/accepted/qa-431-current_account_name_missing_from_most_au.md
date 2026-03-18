# current-account-name missing from most authenticated pages

## Status

resolved

## Severity

medium

## Scope

app

## Description

The  [data-role="current-account-name"]  span in the navigation is only rendered by  Layouts.app  when the  active_account_name  attribute is passed. Only 3 of 19 LiveViews that render  Layouts.app  pass this attribute:  AccountLive.Index ,  AccountLive.Settings , and  IntegrationLive.Index . The remaining 16 LiveViews ( AccountLive.Members ,  DashboardLive.Editor ,  InvitationLive.Send ,  AiLive.Chat ,  CorrelationLive.Index ,  AiLive.Insights ,  IntegrationLive.SyncHistory , etc.) do not pass  active_account_name , so the current account name disappears from the navbar when navigating to those pages. Reproduced: Log in as  qa@example.com , navigate to  /accounts  (account name visible in nav), then navigate to  /accounts/members  — the  [data-role="current-account-name"]  element is absent. The  ActiveAccountHook  already assigns  active_account_name  to the socket on mount for all authenticated LiveViews. The fix is for each LiveView to pass  active_account_name={@active_account_name}  (or the equivalent from their assigns) to  <Layouts.app> .

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Added active_account_name={assigns[:active_account_name]} to all 16 LiveView Layouts.app calls that were missing it. The ActiveAccountHook already assigns the value — each LiveView just needed to forward it to the layout. All tests pass.
