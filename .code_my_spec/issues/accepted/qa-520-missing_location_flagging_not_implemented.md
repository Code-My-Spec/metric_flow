# Missing-location flagging not implemented (criterion 4862)

## Status

resolved

## Severity

high

## Scope

app

## Description

When a previously configured location ID is no longer returned by the GBP API (e.g., a deleted or revoked location), the accounts page shows no warning, flag, or indicator. The manual entry field is pre-filled with the old location ID with no UI feedback that it may be invalid. The acceptance criterion requires the system to flag missing/unavailable locations rather than silently pre-filling the stale ID. Reproduced by setting  included_locations  to  ["accounts/123/locations/deleted-loc-1"]  in the integration's  provider_metadata , then navigating to  /integrations/connect/google_business/accounts . The field shows the stale ID with no warning. This requires the GBP API fetch to return results in order to compare configured locations against live ones. The feature is blocked until  list_google_business_locations  returns data.

## Source

QA Story 520 — `.code_my_spec/qa/520/result.md`

## Resolution

Implemented missing-location flagging for the google_business accounts page. Added compute_missing_locations/3 helper that compares the configured included_locations array against the live-fetched accounts list (by ID). When any configured location IDs are absent from the API results, the list is passed as @missing_locations. The render_account_selection template now renders a data-role='missing-location' warning alert listing each unavailable location ID (each with data-role='location-unavailable') when @missing_locations is non-empty. The flag only triggers when the API actually returns locations (fetched_accounts \!= []), so it correctly does not fire when the API is unavailable with a test token. Files changed: lib/metric_flow_web/live/integration_live/connect.ex. Verified: all 2716 tests pass.
