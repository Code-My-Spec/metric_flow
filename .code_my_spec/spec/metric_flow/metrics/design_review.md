# Design Review

## Overview

Reviewed the MetricFlow.Metrics context and its two child components: Metric (schema) and MetricRepository (data access layer). The overall architecture is sound — the layering is clear, types are consistent, and the repository provides a complete and well-specified query API. Three issues were identified and fixed before this review was written.

## Architecture

- Separation of concerns is correct: Metric handles schema and validation, MetricRepository handles all DB access, and the context exposes the public API via delegation.
- The Metric schema is appropriately narrow — it defines fields, constraints, and a single changeset/2 function with no repository logic leaking in.
- MetricRepository follows the data access layer pattern precisely: all functions accept a Scope struct, filter by user_id, and use Repo directly. No business logic is present in the repository.
- The context acts as a pure delegation boundary. After fixes, every context function delegates to MetricRepository with no direct Repo calls at the context level.
- All @spec types are consistent with component descriptions. Functions using float aggregation (sum, avg, min, max) correctly type the value field as float. The count field in aggregate_metrics/3 is correctly typed as integer. The query_time_series/3 return type correctly uses Date.t() for the grouped date value.
- All functions belong to their respective components. No misplaced logic was found.
- Test assertions are internally consistent. No contradictions were found across any function's assertion list.
- Dependencies are correctly scoped: MetricRepository depends on MetricFlow.Infrastructure.Repo and MetricFlow.Metrics.Metric; the context depends on MetricFlow.Users and MetricFlow.Metrics.MetricRepository. No cross-boundary violations exist.
- The provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks) align with the Integration schema's provider enum defined in the Integrations context, which is appropriate for a normalized metric store.

## Integration

- MetricFlow.Metrics is consumed by MetricFlow.Ai, MetricFlow.Correlations, MetricFlow.Dashboards, MetricFlow.DataSync, and MetricFlowWeb.CorrelationLive.Goals, as confirmed by the dependency graph.
- DataSync.SyncWorker uses create_metric/2 and create_metrics/2 to persist normalized provider data — both are fully specified in MetricRepository and delegated correctly from the context.
- Correlations and Dashboards consume query_time_series/3 for time-based analysis and charting — this function is specified in MetricRepository and now correctly listed as a delegate in the context.
- MetricFlow.Ai uses aggregate_metrics/3 for insights generation — this function is specified in MetricRepository and now correctly listed as a delegate.
- MetricFlowWeb.CorrelationLive.Goals uses list_metric_names/2 for metric selection — this function is specified in MetricRepository and now correctly listed as a delegate.
- The delete_metrics_by_provider/2 function provides the integration cleanup path when a provider is disconnected, scoped to the user for multi-tenant safety.
- The Metric schema's user_id foreign key connects to MetricFlow.Users.User, with an assoc_constraint enforcing referential integrity at the changeset level.

## Issues

- **Incomplete Delegates in context spec**: create_metrics/2, query_time_series/3, aggregate_metrics/3, and list_metric_names/2 were missing from the Delegates section despite having corresponding functions in MetricRepository. Fixed by adding all four to the Delegates section.
- **Direct DB access in context Process steps**: The Process steps for create_metrics/2, query_time_series/3, aggregate_metrics/3, and list_metric_names/2 described direct Ecto/Repo operations rather than delegation. Fixed by replacing each with a single delegation step pointing to MetricRepository.
- **MetricFlow.Infrastructure as a context dependency**: The context listed MetricFlow.Infrastructure as a direct dependency. Contexts must not access the infrastructure layer directly — that responsibility belongs to the repository. Fixed by replacing MetricFlow.Infrastructure with MetricFlow.Metrics.MetricRepository in the context's Dependencies section.

## Conclusion

The MetricFlow.Metrics context is ready for implementation. All three issues found during review have been fixed in the spec files. The schema, repository, and context are consistent with each other and with the project's architectural patterns. No further action items remain.
