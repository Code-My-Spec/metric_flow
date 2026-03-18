# BDD spec references google_ads provider routes that do not exist

## Status

resolved

## Severity

low

## Scope

qa

## Description

The brief (Scenarios 1–5, 7–8) references routes like  /integrations/connect/google_ads ,  /integrations/connect/google_ads/accounts , and  /integrations/oauth/callback/google_ads?... . None of these routes resolve — they all redirect to  /integrations/connect  because  google_ads  is not a recognized provider key. The correct provider key is  google . The spec was written against a different data model than what was implemented. Tests should be updated to use the actual provider key  google  for scenarios involving Google Ads or Google Analytics.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

BDD spex being updated by background agent to use :google provider instead of :google_ads/:google_analytics routes.
