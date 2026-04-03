# MetricFlow.DataSync

Sync scheduling, execution, and history tracking. Orchestrates automated daily syncs and manual data pulls from external platforms (Google Ads, Google Analytics, Facebook Ads, QuickBooks), persisting unified metrics through the Metrics context.

## Type

context

## Delegates

- get_sync_job/2: MetricFlow.DataSync.SyncJobRepository.get_sync_job/2
- list_sync_jobs/1: MetricFlow.DataSync.SyncJobRepository.list_sync_jobs/1
- get_sync_history/2: MetricFlow.DataSync.SyncHistoryRepository.get_sync_history/2
- list_sync_history/2: MetricFlow.DataSync.SyncHistoryRepository.list_sync_history/2

## Functions

### sync_integration/2

Triggers a manual sync for a specific integration.

```elixir
@spec sync_integration(Scope.t(), atom()) :: {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :not_connected}
```

**Process**:
1. Verify integration exists via MetricFlow.Integrations.get_integration/2
2. Return error if integration not found or not connected
3. Create SyncJob record with status :pending
4. Enqueue SyncWorker job via Oban with integration_id and user_id
5. Return ok tuple with sync job, or error from any step

**Test Assertions**:
- returns ok tuple with sync job for connected integration
- sync job has status :pending
- Oban job is enqueued with correct args
- returns error tuple with :not_found when integration doesn't exist
- returns error tuple with :not_connected when integration exists but is disconnected

### schedule_daily_syncs/0

Schedules sync jobs for all active integrations across all users.

```elixir
@spec schedule_daily_syncs() :: {:ok, integer()}
```

**Process**:
1. Query all active integrations via MetricFlow.Integrations.IntegrationRepository
2. Filter to integrations that are not expired
3. For each integration, create SyncJob record with status :pending
4. Enqueue SyncWorker job via Oban for each integration
5. Return ok tuple with count of scheduled jobs

**Test Assertions**:
- schedules sync jobs for all active integrations
- does not schedule jobs for expired integrations
- does not schedule jobs for integrations without refresh tokens
- returns count of scheduled jobs
- Oban jobs are enqueued with correct args

### list_sync_history/2

Lists sync history for scoped user, optionally filtered by integration.

```elixir
@spec list_sync_history(Scope.t(), keyword()) :: list(SyncHistory.t())
```

**Process**:
1. Delegate to SyncHistoryRepository.list_sync_history/2
2. Pass scope and filter options (provider, limit, offset)
3. Return list of sync history records ordered by most recent

**Test Assertions**:
- returns list of sync history for scoped user
- returns empty list when user has no sync history
- filters by provider when provider option provided
- limits results when limit option provided
- offsets results when offset option provided
- sync history records are ordered by most recent first

### get_sync_job/2

Retrieves a specific sync job for the scoped user.

```elixir
@spec get_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with sync job when found
- returns error tuple with :not_found when sync job doesn't exist
- returns error tuple with :not_found when sync job belongs to different user

### list_sync_jobs/1

Lists all sync jobs for the scoped user.

```elixir
@spec list_sync_jobs(Scope.t()) :: list(SyncJob.t())
```

**Test Assertions**:
- returns list of sync jobs for scoped user
- returns empty list when user has no sync jobs
- sync jobs are ordered by most recently created
- includes jobs with all statuses (pending, running, completed, failed)

### cancel_sync_job/2

Cancels a pending or running sync job.

```elixir
@spec cancel_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :invalid_status}
```

**Process**:
1. Get sync job via SyncJobRepository.get_sync_job/2
2. Return error if sync job not found
3. Verify sync job status is :pending or :running
4. Return error if status is :completed, :failed, or :cancelled
5. Update sync job status to :cancelled
6. Cancel Oban job if job is :pending
7. Return ok tuple with updated sync job

**Test Assertions**:
- returns ok tuple with cancelled sync job for pending job
- returns ok tuple with cancelled sync job for running job
- cancels Oban job when status is pending
- returns error tuple with :not_found when sync job doesn't exist
- returns error tuple with :invalid_status when job is already completed
- returns error tuple with :invalid_status when job is already failed
- returns error tuple with :invalid_status when job is already cancelled

### get_sync_history/2

Retrieves a specific sync history record for the scoped user.

```elixir
@spec get_sync_history(Scope.t(), integer()) :: {:ok, SyncHistory.t()} | {:error, :not_found}
```

**Test Assertions**:
- returns ok tuple with sync history when found
- returns error tuple with :not_found when sync history doesn't exist
- returns error tuple with :not_found when sync history belongs to different user

## Dependencies

- MetricFlow.Integrations
- MetricFlow.Metrics
- MetricFlow.Users

## Components

### MetricFlow.DataSync.SyncJob

Ecto schema representing scheduled or running sync jobs. Stores user_id, integration_id, provider, status (pending, running, completed, failed, cancelled), started_at, and completed_at timestamps. Belongs to User and Integration. Provides status transition functions and running time calculations.

### MetricFlow.DataSync.SyncHistory

Ecto schema representing completed sync records with outcome tracking. Stores user_id, integration_id, provider, status (success, partial_success, failed), records_synced count, error messages, started_at, and completed_at timestamps. Belongs to User and Integration. Provides success rate queries and error analysis functions.

### MetricFlow.DataSync.SyncJobRepository

Data access layer for SyncJob CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_jobs/1, get_sync_job/2, create_sync_job/3, update_sync_job_status/3, and cancel_sync_job/2 functions.

### MetricFlow.DataSync.SyncHistoryRepository

Data access layer for SyncHistory read operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_history/2 with filter options (provider, limit, offset), get_sync_history/2, and create_sync_history/2 functions. Queries ordered by most recent first.

### MetricFlow.DataSync.Scheduler

Oban scheduled job that runs daily to enqueue sync jobs for all active integrations. Uses cron schedule to trigger at configured time. Queries all integrations, filters to active/valid tokens, creates SyncJob records, and enqueues SyncWorker jobs. Provides schedule_daily_syncs/0 function.

### MetricFlow.DataSync.SyncWorker

Oban worker that executes data sync operations. Receives integration_id and user_id in args. Updates SyncJob status to running, retrieves integration tokens, delegates to appropriate DataProvider based on provider, persists metrics via MetricFlow.Metrics, creates SyncHistory record with results, and updates SyncJob status to completed or failed. Handles token refresh when tokens are expired.

### MetricFlow.DataSync.DataProviders.Behaviour

Behaviour contract defining callbacks all data provider implementations must implement. Providers implement fetch_metrics/2 to retrieve data from external APIs using OAuth tokens, transform provider-specific data formats to unified metric structures, and return ok tuple with metrics list or error tuple with failure reason. Enables separation of concerns between sync orchestration and provider-specific API integration.

### MetricFlow.DataSync.DataProviders.GoogleAds

Google Ads provider implementation. Fetches campaign performance metrics (impressions, clicks, cost, conversions) using Google Ads API. Transforms API response to unified metric format with metric_type, metric_name, value, recorded_at, and metadata fields. Handles pagination and date range filtering. Stores metrics with provider :google_ads.

### MetricFlow.DataSync.DataProviders.GoogleAnalytics

Google Analytics provider implementation using Google Analytics Data API (GA4). Fetches website traffic metrics (sessions, pageviews, bounce_rate, average_session_duration) with dimension breakdowns. Transforms API response to unified metric format. Handles property selection and date range filtering. Stores metrics with provider :google_analytics.

### MetricFlow.DataSync.DataProviders.FacebookAds

Facebook Ads provider implementation using Facebook Marketing API. Fetches ad campaign metrics (impressions, clicks, spend, conversions, CPM, CPC) from Ad Insights endpoint. Transforms API response to unified metric format. Handles pagination and date range filtering. Stores metrics with provider :facebook_ads.

### MetricFlow.DataSync.DataProviders.QuickBooks

QuickBooks provider implementation using QuickBooks Online API. Fetches financial metrics (revenue, expenses, profit, accounts_receivable, accounts_payable) from Profit and Loss and Balance Sheet reports. Transforms API response to unified metric format. Handles date range filtering and account hierarchy. Stores metrics with provider :quickbooks.

