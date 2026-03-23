# Unexpected bare "google" provider card in the platform grid

## Status

resolved

## Severity

medium

## Scope

app

## Description

A sixth card with  data-platform="google"  appears in the platform grid alongside the five
canonical providers. This card has no description, shows "Not connected", and clicking
"Connect" initiates a Google OAuth flow (distinct from  google_ads ,  google_analytics ,
etc.). This card appears because  Integrations.list_providers()  returns  :google  as a
configured key, and  build_provider_list/1  unions configured keys with canonical keys.
There is no entry for  :google  in  @canonical_providers  or  @provider_metadata , so it
renders with a derived display name and empty description. A bare "Google" card with no description alongside separate "Google Ads", "Google
Analytics", and "Google Search Console" cards is confusing — users do not know what
"Google" connects without a description. The  @provider_metadata  map should include an
entry for  :google , or the  list_providers()  return should be filtered to exclude the
base  google  OAuth key from the selection grid UI.

## Source

QA Story 435 — `.code_my_spec/qa/435/result.md`

## Resolution

Filtered :google OAuth parent key from provider grid. Added @oauth_parent_keys MapSet in connect.ex and excluded them via MapSet.difference in build_provider_list/1. Files changed: lib/metric_flow_web/live/integration_live/connect.ex. Verified: mix compile + MIX_ENV=test mix agent_test (2705 tests, 0 failures).
