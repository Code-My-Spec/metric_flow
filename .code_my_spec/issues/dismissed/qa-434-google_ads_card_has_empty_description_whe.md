# Google Ads card has empty description when shown from integration data

## Severity

low

## Scope

app

## Description

The  google_ads  card on the platform selection page ( /integrations/connect ) shows an empty description paragraph. This is because  google_ads  is not in  @platform_metadata  — it appears only because a legacy integration record exists. The  build_unknown_platform/2  helper is called, which sets  description: "" . If  google_ads  should remain a visible platform (separate from the consolidated  google ), it needs a metadata entry. If it is superseded by the  google  canonical platform, old  google_ads  integrations should be migrated or the UI should show the  google  metadata for them. Reproduction: Navigate to  http://localhost:4070/integrations/connect . The "Google Ads" card shows no description text beneath the platform name.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Dismissed — low severity, below medium+ triage threshold. This is a symptom of the canonical platform list mismatch (accepted as `qa-434-platform_list_does_not_include_google_ana.md`). Fixing the canonical platforms will resolve this.
