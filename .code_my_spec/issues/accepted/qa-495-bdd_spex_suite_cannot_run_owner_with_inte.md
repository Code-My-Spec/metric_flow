# BDD spex suite cannot run: owner_with_integrations given not defined in SharedGivens

## Severity

high

## Scope

qa

## Description

All 8 BDD spec files for story 495 use  given_ :owner_with_integrations  as their primary setup step, but this given is not defined anywhere in  test/support/shared_givens.ex . Running  mix spex  for any of the criterion files under  test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/  will fail at compile time or produce a runtime error because the given is unresolvable. The same given is also referenced by all spec files in story 493 ( test/spex/493_cross-platform_metric_normalization_and_mapping/ ), so this is a systemic gap affecting at least two stories. The missing given needs to: register or look up a confirmed user, create a connected integration record for that user, and return  %{owner_conn: authenticated_conn}  in the context so that  context.owner_conn  is a valid authenticated connection for  live/2  calls. Reproduction: run  mix spex test/spex/495_correct_aggregation_of_derived_and_calculated_metrics/criterion_4611_system_distinguishes_between_rawadditive_metrics_eg_clicks_spend_impressions_and_derivedcalculated_metrics_eg_cpc_ctr_conversion_rate_roas_spex.exs  — all scenarios will fail because  :owner_with_integrations  is not found in  MetricFlowSpex.SharedGivens .

## Source

QA Story 495 — `.code_my_spec/qa/495/result.md`

## Resolution

Added `:owner_with_integrations` given to `test/support/shared_givens.ex`. It follows the same register-then-login pattern as `:user_logged_in_as_owner`, then creates an integration record via `IntegrationsFixtures.integration_fixture/1` (OAuth can't be done through UI in tests). Returns `%{owner_conn: authed_conn, owner_email: email, owner_password: password}`.

Files changed:
- `test/support/shared_givens.ex` — added `:owner_with_integrations` given

Verified: Story 495 criterion 4611 spex passes (1 test, 0 failures).
