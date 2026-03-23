# Location row data-role attributes missing from template (criteria 4855–4856)

## Status

resolved

## Severity

medium

## Scope

app

## Description

The  render_account_selection/1  template in  connect.ex  uses generic field bindings ( property.name ,  property.account ,  property.id ) in  data-role="account-option"  items. The acceptance criteria specify distinct  data-role  attributes for GBP-specific location fields:  data-role="location-title" ,  data-role="location-address" ,  data-role="location-store-code" , and  data-role="location-account-name" . These attributes are absent from the current template, meaning automated tests based on the acceptance criteria selectors will fail when location data is available.

## Source

QA Story 520 — `.code_my_spec/qa/520/result.md`

## Resolution

Added GBP-specific data-role attributes to the render_account_selection template in connect.ex. When the provider is google_business, location rows now render: data-role='location-title' for the location name, data-role='location-account-name' for the account, data-role='location-address' for the address (when present), and data-role='location-store-code' for the store code (when present). For other providers the original generic layout is preserved. Files changed: lib/metric_flow_web/live/integration_live/connect.ex. Verified: all 2716 tests pass.
