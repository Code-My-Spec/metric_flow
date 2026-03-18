# Older failed entries expose internal Elixir module names in error messages

## Status

accepted

## Severity

low

## Scope

app

## Description

Some persisted failed sync entries (from 2026-03-17) display error messages that include full Elixir module paths visible to the user, for example: "MetricFlow.DataSync.DataProviders.FacebookAds: missing_ad_account_id" "MetricFlow.DataSync.DataProviders.GoogleAnalytics: No Google Analytics property configured. Go to the integration's account selection to choose a property.; MetricFlow.DataSync.DataProviders.GoogleAds: No Google Ads customer ID configured. Go to the integration's account selection to choose an account." These appear in  [data-role="sync-error"]  elements on the sync history page for older records (those dated 2026-03-17). Newer records (2026-03-18) show cleaner messages without module prefixes (e.g. just "missing_ad_account_id" or "No Google Ads customer ID configured..."). This suggests the error message format changed between the two dates — older records were stored with the module name prepended, newer ones are stored without it. The raw module path should not be surfaced in the UI. Reproduced at:  http://localhost:4070/integrations/sync-history  — scroll to entries dated 2026-03-17 with status "Failed".

## Source

QA Story 518 — `.code_my_spec/qa/518/result.md`
