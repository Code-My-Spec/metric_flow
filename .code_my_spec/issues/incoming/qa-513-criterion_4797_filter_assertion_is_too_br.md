# criterion_4797 filter assertion is too broad — refutes "Success" string but filter button always renders it

## Status

incoming

## Severity

low

## Scope

qa

## Description

In  criterion_4797_sync_failures_for_individual_customers_..._spex.exs , the scenario "filtering by Failed shows only failed entries" contains: refute html =~ "Success",
       "Expected the Success entry to be hidden after clicking the Failed filter, got: #{html}" When the Failed filter is active, the sync history entries list correctly shows only failed entries. However, the filter tab button  <button data-role="filter-success">Success</button>  is always rendered in the HTML regardless of which filter is active. The  html =~ "Success"  match hits the button text, causing the refute to fail. The application filtering behavior is correct. The spex assertion must be scoped to the history entries only, e.g., checking that no  data-role="sync-history-entry"  element contains "badge-success" rather than checking the full page HTML for the string "Success". Reproduction: Run  mix spex test/spex/513_sync_google_business_profile_reviews/criterion_4797_...  — the third scenario ("filtering by Failed shows only failed entries") fails at the  then_ "only the failed entry is shown"  step.

## Source

QA Story 513 — `.code_my_spec/qa/513/result.md`
