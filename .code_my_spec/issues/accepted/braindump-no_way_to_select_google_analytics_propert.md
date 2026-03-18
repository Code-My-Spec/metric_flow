# No way to select Google Analytics property or Google Ads customer during OAuth connect flow

## Status

resolved

## Severity

high

## Scope

app

## Description

After connecting Google via OAuth, there is no UI step to select which GA4 property or Google Ads customer ID to use. The provider_metadata fields (property_id, customer_id) are left empty, causing all syncs to fail with missing_property_id / missing_customer_id errors. The /integrations/connect/:provider/accounts page exists but does not populate these fields from the Google API. Users need a step in the connect flow (or a post-connect settings page) to browse and select their GA4 property and Google Ads customer.

## Source

Braindump import

## Resolution

Implemented GA4 property selection on /integrations/connect/:provider/accounts. Created GoogleAccounts module to list GA4 properties via Admin API. Updated connect LiveView accounts view to fetch and display properties as selectable options. Added update_provider_metadata to save property_id selection. After OAuth, users can now select their GA4 property before syncing. All 2560 tests pass (1 pre-existing cassette failure).
