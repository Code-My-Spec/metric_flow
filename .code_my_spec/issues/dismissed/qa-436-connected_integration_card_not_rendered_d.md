# Connected integration card not rendered despite seeded integration

## Severity

high

## Scope

app

## Description

The "Connected Platforms" section renders the heading but no integration card, even though a
 google_ads  integration record exists in the database for  qa@example.com  (id=1, user_id=2). Root cause: The running Phoenix server is executing a stale in-memory version of
 MetricFlowWeb.IntegrationLive.Index . The currently live module's  build_platform_list/0  only calls
 Integrations.list_providers()  (which returns  [:google] ) and does NOT merge the  @canonical_platforms
list. The updated source file on disk adds  @canonical_platforms  and a union step, but this change was
not loaded into the running server process. The  data-phx-loc  annotations in the rendered HTML point to the new source line numbers, which
suggests the beam was recompiled from the updated source but hot-reload did not propagate the module
attribute change into the running VM — this typically requires a full server restart. As a result: @platforms  in the LiveView assign is  [%{key: :google, ...}]  only The  google_ads  integration exists in the database and is returned by  Integrations.list_integrations/1 find_integration(@integrations, :google_ads)  would return the integration IF  :google_ads  were in
 @platforms , but it isn't The Connected Platforms loop renders nothing Available Platforms shows only Google (not Google Ads, Facebook Ads, Google Analytics) Reproduction: Start the Phoenix server, navigate to  /integrations  while logged in as a user with a
 google_ads  integration. Observed on  http://localhost:4070/integrations . Fix: Restart the Phoenix server so the updated  IntegrationLive.Index  module (with  @canonical_platforms )
is loaded fresh. All connected-card scenarios are expected to pass after restart.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Triage Notes

Dismissed — not a real app bug. The underlying code issue (missing canonical platforms in Index) was already fixed in qa-434-integrations_index_missing_canonical_platforms. The QA agent tested against a stale server that hadn't been restarted after the fix was applied. The issue itself confirms the fix is on disk and a restart resolves it.
