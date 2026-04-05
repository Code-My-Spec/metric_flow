# Design Review

## Overview

Reviewed the MetricFlow.Reviews context and its three child components: Review (schema), ReviewRepository (module), and ReviewMetrics (module). The overall architecture is sound with clear separation of concerns and proper multi-tenant scoping throughout. After fixing a missing Functions section in ReviewRepository and adding a `count_reviews/1` function, the design is ready for implementation.

## Architecture

- Separation of concerns is clean: Review owns schema and validation, ReviewRepository owns all Ecto queries, ReviewMetrics owns rolling metric computation, and the context exposes the public API.
- The schema component (Review) correctly holds only changeset logic and field definitions. No query logic leaks into it.
- ReviewMetrics is correctly a pure computation module — it queries raw aggregates from the database and reduces them in Elixir, with no side effects.
- ReviewRepository follows the standard repository pattern with scoped get/list/create/delete operations plus a count function. All operations accept Scope as the first parameter.
- The context's Delegates section accurately reflects pass-through functions to ReviewRepository. The two non-delegated context functions (`review_count/1` and `recent_reviews/2`) are thin wrappers that add default option values before calling the repository.
- ReviewMetrics is listed as a dependency of the context but `query_rolling_review_metrics/2` is implemented in ReviewMetrics and called from the context — this is consistent with the component descriptions.

## Integration

- The context delegates `list_reviews/2`, `get_review/2`, `create_reviews/2`, and `delete_reviews_by_provider/2` directly to ReviewRepository with matching signatures.
- `review_count/1` in the context calls `ReviewRepository.count_reviews/1` (added during review).
- `recent_reviews/2` in the context calls `ReviewRepository.list_reviews/2` with limit and provider opts, using ReviewRepository as its data source.
- `query_rolling_review_metrics/2` in the context delegates to `ReviewMetrics.query_rolling_review_metrics/2`.
- ReviewMetrics depends on `MetricFlow.Reviews.Review` (for the schema), `MetricFlow.Repo` (for queries), and `MetricFlow.Users.Scope` — all valid dependencies within the boundary.
- ReviewRepository depends on `MetricFlow.Reviews.Review`, `MetricFlow.Repo`, and `MetricFlow.Users.Scope` — all valid.
- Review schema depends on `MetricFlow.Integrations.Integration` and `MetricFlow.Users.User` for associations — these are cross-context dependencies that must be permitted by Boundary configuration.

## Issues

- ReviewRepository spec was missing its entire Functions section. Added `list_reviews/2`, `get_review/2`, `create_reviews/2`, `count_reviews/1`, and `delete_reviews_by_provider/2` with full specs, process steps, and test assertions.
- Context `review_count/1` referenced counting reviews but no corresponding repository function existed. Added `count_reviews/1` to ReviewRepository spec and updated the context spec process to delegate to it explicitly.
- Context `recent_reviews/2` process said "Delegate to ReviewRepository" but did not specify which function. Updated process to clarify it calls `ReviewRepository.list_reviews/2` with limit and provider opts.
- ReviewRepository description in the context spec's Components section did not mention `count_reviews/1`. Updated to include it.

## Conclusion

The MetricFlow.Reviews context is ready for implementation. All child component specs are complete with functions, typespecs, process steps, and test assertions. The component boundaries are well-defined and integration points are clearly specified. No blocking issues remain.
