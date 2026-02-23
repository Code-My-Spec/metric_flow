# Design Review

## Overview

Reviewed MetricFlow.DataSync context with 11 child components: 2 schemas (SyncJob, SyncHistory), 2 repositories (SyncJobRepository, SyncHistoryRepository), 2 Oban workers (Scheduler, SyncWorker), 1 behaviour contract (DataProviders.Behaviour), and 4 data provider implementations (GoogleAnalytics, GoogleAds, FacebookAds, QuickBooks). The architecture is sound with clear separation of concerns and follows established patterns from the Integrations context.

## Architecture

- Separation of concerns is clean: schemas handle validation, repositories handle data access with Scope isolation, workers handle background processing, and providers handle external API integration
- Component type usage is appropriate: Ecto schemas with changeset/2 helpers, repository pattern with Scope-based multi-tenancy, Oban workers with perform/1 callbacks, behaviour contract with provider implementations
- DataProviders.Behaviour defines a consistent contract (fetch_metrics/2, provider/0, required_scopes/0) that all four providers implement uniformly
- No circular dependencies: data flows from Scheduler -> SyncWorker -> DataProviders -> Metrics, with SyncJob/SyncHistory tracking state through repositories
- Provider enum values are consistent across SyncJob, SyncHistory, and all DataProvider implementations (:google_analytics, :google_ads, :facebook_ads, :quickbooks)

## Issues

- **Cross-boundary dependency on IntegrationRepository**: Scheduler spec references `MetricFlow.Integrations.IntegrationRepository.list_all_integrations/0` directly. Per Boundary rules, DataSync should only depend on `MetricFlow.Integrations` (the context facade), not its internal modules. The Integrations context needs a new `list_all_active_integrations/0` function exposed at the context level. Same applies to SyncWorker referencing IntegrationRepository for get_integration/1.
- **Missing unscoped integration lookup**: The Scheduler needs all integrations across all users (not scoped). The current Integrations context only exposes scoped functions. A new `list_all_active_integrations/0` function is needed on the Integrations context that returns integrations with valid tokens, without requiring a Scope.
- **SyncWorker needs integration lookup by ID**: SyncWorker receives `integration_id` in args but IntegrationRepository only supports lookup by (Scope, provider). A `get_integration_by_id/1` or equivalent is needed on the Integrations context for worker use cases.
- **Scheduler references `refresh_token` filtering**: The Integrations context needs to expose `Integration.has_refresh_token?/1` and `Integration.expired?/1` helpers, or the Scheduler filtering should be done inside the Integrations context's new list function.

## Integration

- Context module delegates CRUD to repositories (get_sync_job/2, list_sync_jobs/1, get_sync_history/2, list_sync_history/2) and provides orchestration functions (sync_integration/2, schedule_daily_syncs/0, cancel_sync_job/2)
- SyncWorker is the central orchestrator: reads integration tokens from Integrations context, delegates to DataProviders for data fetching, persists metrics via Metrics context, and tracks state via SyncJob/SyncHistory repositories
- Scheduler triggers daily via Oban cron, creates SyncJobs, and enqueues SyncWorker jobs
- DataProviders transform provider-specific API responses to unified metric format (metric_type, metric_name, value, recorded_at, dimensions, provider)
- Web layer (IntegrationLive.SyncHistory) consumes list_sync_history/2 and get_sync_job/2 from the context

## Conclusion

The DataSync context design is ready for implementation with caveats. The internal architecture (schemas, repositories, workers, providers) is well-structured. Before implementation, the Integrations context needs to expose additional functions: `list_all_active_integrations/0` for the Scheduler and `get_integration_by_id/1` for the SyncWorker. These are additive changes to the Integrations context and do not block DataSync implementation — stub the Integrations functions and implement them in parallel.
