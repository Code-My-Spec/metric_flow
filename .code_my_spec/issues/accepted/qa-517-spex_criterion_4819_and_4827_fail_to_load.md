# Spex criterion 4819 and 4827 fail to load due to test name length exceeding 255 characters

## Status

resolved

## Severity

medium

## Scope

qa

## Description

Two spex files in  test/spex/517_sync_google_business_profile_performance_metrics/  cannot be loaded by ExUnit because their computed test names exceed the 255-character limit: Criterion 4819: spex title is 258 chars — "The following metrics are fetched as daily time series: BUSINESS_IMPRESSIONS_DESKTOP_MAPS, BUSINESS_IMPRESSIONS_DESKTOP_SEARCH, BUSINESS_IMPRESSIONS_MOBILE_MAPS, BUSINESS_CONVERSATIONS, BUSINESS_DIRECTION_REQUESTS, CALL_CLICKS, WEBSITE_CLICKS, BUSINESS_BOOKINGS, BUSINESS_FOOD_ORDERS, BUSINESS_FOOD_MENU_CLICKS" Criterion 4827: spex title is 265 chars — "Google Business Profile performance integration is distinct from GMB Reviews — both use the same account and location config but call different APIs and store different data under different platformServiceType values ('mybusiness' vs 'mybusiness-reviews')" Error:  the computed name of a test must be shorter than 255 characters . Both files need their  spex "..."  title shortened while preserving the meaning.

## Source

QA Story 517 — `.code_my_spec/qa/517/result.md`

## Resolution

Shortened spex title strings in both files: criterion 4819 from 258 to 107 chars, criterion 4827 from 265 to 111 chars. Both compile and should now load in ExUnit without exceeding the 255-character test name limit.
