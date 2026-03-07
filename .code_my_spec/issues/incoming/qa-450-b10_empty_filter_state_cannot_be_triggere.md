# B10 empty filter state cannot be triggered with seed data — all 5 filter types are populated

## Severity

low

## Scope

qa

## Description

The seed script creates exactly one insight per suggestion type (budget_increase, optimization, monitoring, budget_decrease, general), meaning all 5 filter buttons match at least one insight. The  [data-role='no-filter-results-state']  element can never be reached with the current seed data. To enable testing of B10,  qa_seeds_450.exs  should be updated to leave at least one suggestion type with no insights (e.g., omit the  general  type) so the corresponding filter button returns zero results. Alternatively, the brief should note that B10 cannot be tested with 5-type coverage and should acknowledge this as an intentional trade-off.

## Source

QA Story 450 — `.code_my_spec/qa/450/result.md`
