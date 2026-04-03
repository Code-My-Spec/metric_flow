# Google Search Console missing from ProviderDashboard valid providers

## Status

resolved

## Severity

medium

## Scope

app

## Description

google_search_console  was not in  @valid_providers  list in  provider_dashboard.ex , causing  /integrations/google_search_console/dashboard  to redirect to  /integrations  with "Unknown provider: google_search_console" error. Fixed by adding it to the list and  @provider_display_names .

## Source

QA Story 515 — `.code_my_spec/qa/515/result.md`

## Resolution

Fixed in commit d168bfe. Added google_search_console to @valid_providers and @provider_display_names in provider_dashboard.ex.
