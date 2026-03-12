# Brief tests google_analytics platform not present on fresh seeds

## Severity

low

## Scope

qa

## Description

The brief instructs testing Scenarios 1, 2, and 8 against  google_analytics  as a canonical platform. The spec also lists  google_analytics  as a canonical platform. However, the current implementation does not include  google_analytics  in  @canonical_platforms  — the  google_analytics  route and accounts page function (via atom lookup) but the platform does not appear on the selection grid. The brief should be updated to reflect the actual canonical platforms ( google ,  facebook_ads ,  quickbooks ) or the spec/implementation discrepancy should be resolved first.

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Triage Notes

Dismissed — low severity QA scope issue, below medium+ triage threshold. This is a downstream symptom of the canonical platform list mismatch (accepted as `qa-434-platform_list_does_not_include_google_ana.md`). Resolving the app issue will make the brief testable.
