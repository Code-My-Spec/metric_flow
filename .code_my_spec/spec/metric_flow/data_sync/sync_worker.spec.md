# MetricFlow.DataSync.SyncWorker

Oban worker that executes data sync operations. Receives integration_id and user_id in args. Updates SyncJob status to running, retrieves integration tokens, delegates to appropriate DataProvider based on provider, persists metrics via MetricFlow.Metrics, creates SyncHistory record with results, and updates SyncJob status to completed or failed. Handles token refresh when tokens are expired.

## Functions

### perform/1

Oban worker callback that orchestrates the full sync execution for an integration.

```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
```

**Process**:
1. Extract integration_id, user_id, and sync_job_id from Oban.Job args map
2. Update SyncJob status to :running via SyncJobRepository.update_sync_job_status/3
3. Retrieve integration via MetricFlow.Integrations.get_integration_by_id/1
4. Return error :integration_not_found if integration not found
5. Check if tokens are expired using Integration.expired?/1
6. If expired and has_refresh_token?/1 returns true, attempt token refresh via MetricFlow.Integrations.refresh_token/2
7. Return error :token_expired if expired and no refresh token available
8. Look up data provider module using provider_for/1
9. Return error :unsupported_provider if provider not found
10. Call provider.fetch_metrics/2 with integration and options map
11. On success, persist each metric via MetricFlow.Metrics.create_metric/2
12. Count records_synced from successful metric creation
13. Create SyncHistory record with status :success and records_synced count via SyncHistoryRepository.create_sync_history/2
14. Update SyncJob status to :completed via SyncJobRepository.update_sync_job_status/3
15. On failure, create SyncHistory record with status :failed and error message
16. Update SyncJob status to :failed
17. Return :ok on success or {:error, reason} on failure

**Test Assertions**:
- returns :ok when sync completes successfully
- extracts integration_id, user_id, and sync_job_id from Oban.Job args
- updates SyncJob status to :running at start
- retrieves integration using integration_id
- returns error :integration_not_found when integration doesn't exist
- checks if integration tokens are expired using Integration.expired?/1
- attempts token refresh when expired?/1 returns true and has_refresh_token?/1 returns true
- returns error :token_expired when expired and no refresh token available
- looks up provider module based on integration.provider
- returns error :unsupported_provider for unknown providers
- calls provider.fetch_metrics/2 with integration and empty options map
- persists each fetched metric via MetricFlow.Metrics.create_metric/2
- creates SyncHistory with status :success when all metrics persist successfully
- sets records_synced to count of successfully persisted metrics
- updates SyncJob status to :completed on success
- creates SyncHistory with status :failed and error message on fetch failure
- creates SyncHistory with status :failed when metric persistence fails
- updates SyncJob status to :failed on any error
- includes error message in SyncHistory when provider.fetch_metrics/2 fails
- includes error message in SyncHistory when token refresh fails
- wraps sync execution in transaction for data consistency
- handles network errors gracefully with error tuple
- handles database errors gracefully with error tuple
- logs sync start and completion events
- logs errors with context (integration_id, user_id, provider)

### provider_for/1

Maps integration provider enum to data provider module.

```elixir
@spec provider_for(atom()) :: {:ok, module()} | {:error, :unsupported_provider}
```

**Process**:
1. Pattern match provider atom against supported providers
2. Return {:ok, MetricFlow.DataSync.DataProviders.GoogleAnalytics} for :google_analytics
3. Return {:ok, MetricFlow.DataSync.DataProviders.GoogleAds} for :google_ads
4. Return {:ok, MetricFlow.DataSync.DataProviders.FacebookAds} for :facebook_ads
5. Return {:ok, MetricFlow.DataSync.DataProviders.QuickBooks} for :quickbooks
6. Return {:error, :unsupported_provider} for any other atom

**Test Assertions**:
- returns {:ok, GoogleAnalytics} for :google_analytics provider
- returns {:ok, GoogleAds} for :google_ads provider
- returns {:ok, FacebookAds} for :facebook_ads provider
- returns {:ok, QuickBooks} for :quickbooks provider
- returns error :unsupported_provider for :github provider
- returns error :unsupported_provider for :google provider
- returns error :unsupported_provider for :gitlab provider
- returns error :unsupported_provider for :bitbucket provider
- returns error :unsupported_provider for nil
- returns error :unsupported_provider for unknown atom

## Dependencies

- Oban
- MetricFlow.Integrations
- MetricFlow.Metrics
- MetricFlow.DataSync.SyncJobRepository
- MetricFlow.DataSync.SyncHistoryRepository
- MetricFlow.DataSync.DataProviders.GoogleAnalytics
- MetricFlow.DataSync.DataProviders.GoogleAds
- MetricFlow.DataSync.DataProviders.FacebookAds
- MetricFlow.DataSync.DataProviders.QuickBooks
