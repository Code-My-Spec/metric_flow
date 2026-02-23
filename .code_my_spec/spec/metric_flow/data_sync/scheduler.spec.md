# MetricFlow.DataSync.Scheduler

Oban scheduled job that runs daily to enqueue sync jobs for all active integrations. Uses cron schedule to trigger at configured time (e.g., 2am UTC). Queries all integrations across all users, filters to integrations with valid tokens, creates SyncJob records, and enqueues SyncWorker jobs.

## Functions

### perform/1

Oban worker callback invoked when the cron schedule triggers.

```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
```

**Process**:
1. Extract args from Oban.Job struct (args are empty for cron jobs)
2. Delegate to schedule_daily_syncs/0
3. Return :ok on success, or error tuple from schedule_daily_syncs/0

**Test Assertions**:
- returns :ok when schedule_daily_syncs/0 succeeds
- delegates to schedule_daily_syncs/0
- handles Oban.Job struct with empty args
- returns error tuple when schedule_daily_syncs/0 fails

### schedule_daily_syncs/0

Schedules sync jobs for all active integrations across all users.

```elixir
@spec schedule_daily_syncs() :: {:ok, integer()}
```

**Process**:
1. Query all active integrations via MetricFlow.Integrations.list_all_active_integrations/0
2. Filter to integrations that are not expired using Integration.expired?/1
3. Filter to integrations that have refresh tokens using Integration.has_refresh_token?/1
4. For each valid integration, create SyncJob record with status :pending via MetricFlow.DataSync.SyncJobRepository.create_sync_job/2
5. For each SyncJob, enqueue SyncWorker job via Oban.insert/1 with integration_id and user_id
6. Count total jobs enqueued
7. Return ok tuple with count of scheduled jobs

**Test Assertions**:
- schedules sync jobs for all active integrations
- creates SyncJob with status :pending for each integration
- enqueues SyncWorker Oban job for each integration
- does not schedule jobs for expired integrations without refresh tokens
- does not schedule jobs for integrations without refresh tokens
- filters out integrations where expired?/1 returns true and has_refresh_token?/1 returns false
- includes integrations where expired?/1 returns true but has_refresh_token?/1 returns true
- returns count of scheduled jobs
- Oban jobs are enqueued with correct args (integration_id, user_id)
- handles empty integration list gracefully
- returns {:ok, 0} when no integrations exist
- creates jobs in transaction to ensure consistency

## Dependencies

- Oban
- MetricFlow.Integrations
- MetricFlow.DataSync.SyncJobRepository
- MetricFlow.DataSync.SyncWorker
