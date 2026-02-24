# Design Review

## Overview

Reviewed the Integrations context and its 4 child components (Integration schema, IntegrationRepository, Providers.Behaviour, Providers.Google). The architecture is sound with clean separation of concerns, no circular dependencies, and a well-structured provider abstraction using Assent. One significant gap exists: the context spec documents no functions despite the implementation exposing a full public API.

## Architecture

- **Separation of concerns is clean**: Schema handles data structure and validation, Repository handles scoped CRUD, Behaviour defines the provider contract, and concrete providers implement it. The context facade orchestrates OAuth flows and delegates data access.
- **Component types are appropriate**: Schema for `Integration`, repository pattern for `IntegrationRepository`, behaviour for the provider contract, and module implementation for Google.
- **Dependency graph is valid**: No circular dependencies detected. Context depends on `Users` (for Scope) and `Infrastructure` (for Repo) — both appropriate cross-boundary dependencies declared via `use Boundary`.
- **Provider abstraction is well-designed**: The three-callback behaviour (`config/0`, `strategy/0`, `normalize_user/1`) keeps providers minimal while Assent handles OAuth complexity. Adding new providers requires only implementing the behaviour.
- **Multi-tenant isolation is consistent**: All repository operations are scoped via `Users.Scope`, preventing cross-user data access to OAuth credentials.
- **`by_provider/2` is redundant**: It's a pure alias for `get_integration/2` adding surface area without value. Consider removing it from the spec.

## Issues

- **Context spec is empty**: `integrations.spec.md` documents no functions. The implementation exposes `authorize_url/1`, `handle_callback/4`, `get_integration/2`, `list_integrations/1`, `delete_integration/2`, and `connected?/2`. These need to be documented in the spec to maintain spec-implementation alignment.
- **Google provider scope inconsistency**: The moduledoc states `analytics.readonly` but the implementation and spec both use `analytics.edit`. The moduledoc should be corrected to match.
- **Google provider has debug logging in config/0**: `Logger.debug` calls in `config/0` log client_id values. These should be removed before production — OAuth credentials should not appear in logs even at debug level.

## Integration

- **Context delegates CRUD to IntegrationRepository**: `get_integration/2`, `list_integrations/1`, `delete_integration/2`, and `connected?/2` are delegated cleanly via `defdelegate`.
- **OAuth flow is orchestrated in the context**: `authorize_url/1` and `handle_callback/4` compose provider lookup, Assent strategy calls, user normalization, and repository persistence into a clean pipeline using `with`.
- **Provider lookup via module attribute**: `@providers` map centralizes provider-to-module mapping, making it easy to add providers.
- **Token persistence uses upsert**: `upsert_integration/3` handles both first-time connections and reconnections via `on_conflict`, which aligns with the "one integration per provider per user" business rule.

## Conclusion

The architecture is ready for implementation with one blocking issue: the context spec (`integrations.spec.md`) must be populated with its public API functions before proceeding. The other issues (redundant `by_provider/2`, Google moduledoc inconsistency, debug logging) are non-blocking but should be addressed during implementation.
