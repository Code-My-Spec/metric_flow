# No page-specific AI chat entry point on correlations and insights pages

## Status

accepted

## Severity

low

## Scope

app

## Description

The brief (B2, B3) checks for a  [data-role="open-ai-chat"]  button or similar page-specific entry point to AI chat on the correlations ( /correlations ) and insights ( /insights ) pages. Neither page has such a button. The only route to AI chat from these pages is the global navigation link  a[href="/chat"]  in the app nav bar. The dashboard ( /dashboard ) does have a  [data-role="open-ai-chat"]  button that presumably carries context (context_type param) to the chat page. The correlations and insights pages are missing equivalent context-aware "Open AI Chat" buttons that would pre-set the context type to  correlation  or  metric  when navigating to chat. AC1 states "User can open AI chat from any report or visualization." The nav link technically satisfies minimal navigation, but there are no context-aware entry points on correlations or insights pages as the dashboard has. Users on these pages cannot open chat with the relevant context pre-populated.

## Source

QA Story 451 — `.code_my_spec/qa/451/result.md`
