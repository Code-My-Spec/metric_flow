# Switch account button shows account name instead of "Switch" label

## Status

resolved

## Severity

low

## Scope

app

## Description

The inactive switch buttons on  /accounts  show the account name as the button label (e.g., a button reads "Client Beta") rather than a generic "Switch" label as specified in the spec ( AccountLive.Index  spec states: "labeled 'Switch' when inactive"). The source at  lib/metric_flow_web/live/account_live/index.ex:68  reads:  {if account.id == @active_account_id, do: "Active", else: account.name} . This creates an ambiguous UI — the button appears to be a link or label rather than a switch action. Reproduced: Log in as  qa@example.com , navigate to  /accounts . All inactive account buttons display the account name rather than "Switch".

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Changed switch button label from account name to 'Switch' for inactive accounts, matching the spec. Active account still shows 'Active'.
