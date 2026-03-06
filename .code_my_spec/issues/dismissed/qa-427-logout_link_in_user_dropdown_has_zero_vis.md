# Logout link in user dropdown has zero visual size and is not directly clickable

## Severity

low

## Scope

qa

## Description

The "Log out" link ( a[href='/users/log-out'] ) is inside a DaisyUI dropdown component ( .dropdown.dropdown-end ). The link reports zero size when the dropdown is collapsed, causing  browser_click(selector: "a[href='/users/log-out']")  to fail with "visible check failed — zero size." To log out via the browser, the dropdown avatar button must first be clicked:  browser_click(selector: ".dropdown.dropdown-end div[tabindex='0']") , then  browser_wait(selector: "a[href='/users/log-out']", state: "visible") , then click the link. The QA plan's auth section should document this pattern. Direct  a[href='/users/log-out']  clicks without opening the dropdown first will fail.

## Source

QA Story 427 — `.code_my_spec/qa/427/result.md`

## Triage Notes

Dismissed — low severity, below medium+ threshold. Expected DaisyUI dropdown behavior. The logout link is hidden inside a dropdown menu and must be opened first.
