# Visiting /integrations/connect/:provider with an unknown atom crashes with Ecto.Query.CastError

## Status

resolved

## Severity

high

## Scope

app

## Description

Navigating to  http://localhost:4070/integrations/connect/unknown_provider  returns a 500 error page with  Ecto.Query.CastError . The LiveView's  handle_provider_params/2  rescues  ArgumentError  from  String.to_existing_atom/1  to handle unknown providers, but the atom  :unknown_provider  already exists in the BEAM (likely defined as a module attribute or used elsewhere), so the rescue does not fire. Instead, the atom is passed to  Integrations.get_integration/2  which queries the database with a value that cannot be cast to the Integration provider Ecto.Enum, resulting in an unhandled crash. The fix should include a guard that checks whether the provider atom is a member of the allowed Ecto.Enum values, or catch  Ecto.Query.CastError  in addition to  ArgumentError .

## Source

QA Story 434 — `.code_my_spec/qa/434/result.md`

## Resolution

Extracted a `validate_provider/1` helper that converts the string to an atom and checks membership against `@valid_provider_keys` (derived from the Ecto.Enum values). Unknown providers now get a clean redirect with flash instead of a 500 crash. Also refactored `handle_provider_params/2` into smaller helpers (`resolve_platform/2`, `fetch_existing_integration/2`, `fetch_authorize_url/1`) to reduce cyclomatic complexity.

**Files changed:**
- `lib/metric_flow_web/live/integration_live/connect.ex` — added `validate_provider/1` guard and extracted helpers

**Verification:** All 2561 tests pass.
