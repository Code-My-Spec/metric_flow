# google_ads is not a registered provider — seed integration never renders on integrations page

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The seed script ( priv/repo/qa_seeds.exs ) creates a  google_ads  integration for  qa@example.com  with  provider_metadata  containing  "selected_accounts": ["Campaign Alpha", "Campaign Beta"] . However,  Integrations.list_providers()  returns only  [:google, :facebook_ads, :quickbooks]  — the atom  :google_ads  is not registered. The integrations index builds its platform list exclusively from  list_providers() , so the google_ads integration record exists in the database but is never rendered on the page. Scenario 6 (selected accounts) and any scenario requiring a "Google Ads" named card cannot be verified. Fix options: (1) Add  :google_ads  to  @default_providers  in  lib/metric_flow/integrations.ex , or (2) Update the seed to create a  google  integration with selected_accounts, since  :google  is a registered provider.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`

## Resolution

Updated the QA seed script to create a `:google` integration instead of `:google_ads`. The `:google` provider is registered in `@default_providers` and will render on the integrations page via `list_providers()`.

**Files changed:**
- `priv/repo/qa_seeds.exs` — changed seed integration provider from `:google_ads` to `:google`

**Verification:** All 2561 tests pass.
