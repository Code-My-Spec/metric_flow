# save_account_selection saves included_locations as a string instead of an array

## Status

resolved

## Severity

medium

## Scope

app

## Description

The  save_account_selection  handler in  connect.ex  saves the manual entry text as a single string to the  included_locations  key (via  metadata_key_for_provider(:google_business)  returning  "included_locations" ). The acceptance criteria describe  included_locations  as an array of location IDs to support multi-location selection. When the metadata is externally set to a JSON array and then loaded by the LiveView,  get_in(integration.provider_metadata, ["included_locations"])  returns the array, which is passed to  @manual_property_id . The form's  value  attribute then receives a list. After saving via the UI, the array is overwritten with a single string. For multi-location selection (described in the acceptance criteria), the save handler must collect and store an array of IDs rather than a single string.

## Source

QA Story 520 — `.code_my_spec/qa/520/result.md`

## Resolution

Fixed save_account_selection to store included_locations as an array for the google_business provider. Added build_metadata_value/2 helper that wraps the account_id in a list [account_id] for :google_business and returns the raw string for all other providers. Also added normalize_selection_for_display/2 to correctly handle reading back an array from provider_metadata (shows first element in the manual input). Files changed: lib/metric_flow_web/live/integration_live/connect.ex. Verified: all 2716 tests pass.
