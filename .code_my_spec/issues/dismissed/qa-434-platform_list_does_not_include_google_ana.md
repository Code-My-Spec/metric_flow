# Platform list does not include google_analytics; google_ads shows only because of existing integration data

## Severity

high

## Scope

app

## Description

The spec ( .code_my_spec/spec/metric_flow_web/integration_live/connect.spec.md ) defines the canonical platform list as  google_ads ,  facebook_ads , and  google_analytics . The current implementation defines  @canonical_platforms  as  google  (consolidated),  facebook_ads , and  quickbooks . The  google_analytics  platform is completely absent from the canonical platform list. The  google_ads  card appears on the platform selection page only because a prior integration record exists in the dev database — it is not in the canonical list, has an empty description, and would disappear on a fresh database. This means users on fresh accounts would not see any Google Ads or Google Analytics option. Reproduction: Navigate to  http://localhost:4070/integrations/connect . No  data-platform="google_analytics"  card is present.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Dismissed — spec bug, not implementation bug. The implementation correctly uses a consolidated `:google` platform covering Ads, Analytics, and Search Console via a single OAuth connection. The spec was out of date listing separate `google_ads` and `google_analytics` entries. Spec updated to match implementation.

## Resolution

Spec updated, no code changes. The connect.spec.md was rewritten to document the correct canonical platforms (`:google`, `:facebook_ads`, `:quickbooks`) and the controller-based OAuth flow.

**Files changed:**
- `.code_my_spec/spec/metric_flow_web/integration_live/connect.spec.md`

**Verification:** Implementation unchanged — spec now matches code.
