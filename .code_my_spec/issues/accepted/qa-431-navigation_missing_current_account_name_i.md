# Navigation missing current-account-name indicator

## Status

resolved

## Severity

high

## Scope

app

## Description

No  [data-role="current-account-name"]  element exists in the navigation on any authenticated page ( /accounts ,  /accounts/settings ,  /integrations ). The spec requires the nav to clearly display which account is currently active. The navigation bar contains only the logo, nav links, theme toggle, and user avatar — no account context indicator. Criterion 3994 fails entirely. Reproduction: Log in, navigate to any authenticated page. Inspect DOM for  [data-role="current-account-name"]  — not found.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

## Resolution

Already implemented — ActiveAccountHook assigns active_account_name, layout renders data-role=current-account-name in navbar.
