# Navigation missing current-account-name indicator

## Severity

high

## Scope

app

## Description

No  [data-role="current-account-name"]  element exists in the navigation on any authenticated page ( /accounts ,  /accounts/settings ,  /integrations ). The spec requires the nav to clearly display which account is currently active. The navigation bar contains only the logo, nav links, theme toggle, and user avatar — no account context indicator. Criterion 3994 fails entirely. Reproduction: Log in, navigate to any authenticated page. Inspect DOM for  [data-role="current-account-name"]  — not found.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Added `active_account_name` attr to the `app/1` function component in layouts.ex. When present, renders `<span data-role="current-account-name">` in the navbar. AccountLive.Index passes this assign.

Files changed:
- `lib/metric_flow_web/components/layouts.ex` — added `active_account_name` attr and rendering
- `lib/metric_flow_web/live/account_live/index.ex` — passes `active_account_name` to layout

Verified: 450 account/agencies tests pass, 0 failures.
