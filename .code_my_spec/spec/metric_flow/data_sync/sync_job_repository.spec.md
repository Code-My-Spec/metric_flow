# MetricFlow.DataSync.SyncJobRepository

Data access layer for SyncJob CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_jobs/1, get_sync_job/2, create_sync_job/3, update_sync_job_status/3, and cancel_sync_job/2 functions.

## Functions

### list_sync_jobs/1

Returns all sync jobs for the scoped user, ordered by most recently created.

```elixir
@spec list_sync_jobs(Scope.t()) :: list(SyncJob.t())
```

**Process**:
1. Build query filtering by user_id from scope
2. Order by inserted_at descending, then id descending
3. Execute query with Repo.all()
4. Return list of sync jobs (empty list if none exist)

**Test Assertions**:
- Returns all sync jobs for scoped user
- Returns empty list when no sync jobs exist
- Only returns sync jobs for scoped user
- Orders by most recently created first
- Enforces multi-tenant isolation
- Returns jobs with all statuses (pending, running, completed, failed, cancelled)

### get_sync_job/2

Retrieves a single sync job for the scoped user by ID.

```elixir
@spec get_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found}
```

**Process**:
1. Build query filtering by user_id from scope and sync job id
2. Execute query with Repo.one()
3. Return {:error, :not_found} if nil
4. Return {:ok, sync_job} if found

**Test Assertions**:
- Returns sync job when it exists for scoped user
- Returns error when sync job doesn't exist
- Returns error when sync job exists for different user
- Enforces multi-tenant isolation
- Works with any sync job status
- Loads association data if preloaded

### create_sync_job/3

Creates a new sync job for the scoped user and integration.

```elixir
@spec create_sync_job(Scope.t(), integer(), map()) :: {:ok, SyncJob.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge user_id from scope and integration_id into attrs
2. Build changeset with SyncJob.changeset/2
3. Insert into database with Repo.insert/1
4. Validate provider is supported
5. Validate integration_id references existing integration
6. Validate user_id references existing user
7. Default status to :pending if not provided

**Test Assertions**:
- Creates sync job with valid attributes
- Returns error with invalid provider
- Returns error with missing required fields
- Returns error with non-existent integration_id
- Returns error with non-existent user_id
- Defaults status to :pending when not provided
- Allows explicit status to be set
- Sets user_id from scope automatically
- Allows optional started_at and completed_at
- Allows optional error_message

### update_sync_job_status/3

Updates the status of an existing sync job and sets appropriate timestamps.

```elixir
@spec update_sync_job_status(Scope.t(), integer(), atom()) :: {:ok, SyncJob.t()} | {:error, :not_found}
```

**Process**:
1. Call get_sync_job/2 to fetch existing sync job
2. Return {:error, :not_found} if sync job doesn't exist
3. Build attrs map with new status
4. If transitioning to :running, set started_at to current UTC time
5. If transitioning to :completed, :failed, or :cancelled, set completed_at to current UTC time
6. Build changeset with SyncJob.changeset/2
7. Update sync job with Repo.update/1
8. Return updated sync job

**Test Assertions**:
- Updates status from :pending to :running
- Updates status from :running to :completed
- Updates status from :running to :failed
- Sets started_at when transitioning to :running
- Sets completed_at when transitioning to :completed
- Sets completed_at when transitioning to :failed
- Sets completed_at when transitioning to :cancelled
- Returns error when sync job doesn't exist for scoped user
- Returns error when sync job exists for different user
- Preserves existing timestamps when not transitioning
- Enforces multi-tenant isolation

### cancel_sync_job/2

Cancels a pending or running sync job by setting status to :cancelled.

```elixir
@spec cancel_sync_job(Scope.t(), integer()) :: {:ok, SyncJob.t()} | {:error, :not_found} | {:error, :invalid_status}
```

**Process**:
1. Call get_sync_job/2 to fetch existing sync job
2. Return {:error, :not_found} if sync job doesn't exist
3. Check if sync job status is :pending or :running
4. Return {:error, :invalid_status} if status is :completed, :failed, or :cancelled
5. Build attrs map with status :cancelled and completed_at set to current UTC time
6. Build changeset with SyncJob.changeset/2
7. Update sync job with Repo.update/1
8. Return updated sync job

**Test Assertions**:
- Cancels sync job with :pending status
- Cancels sync job with :running status
- Returns error when sync job status is :completed
- Returns error when sync job status is :failed
- Returns error when sync job status is :cancelled
- Sets completed_at when cancelling
- Returns error when sync job doesn't exist for scoped user
- Returns error when sync job exists for different user
- Enforces multi-tenant isolation
- Only allows cancellation of active jobs

## Dependencies

- Ecto.Query
- MetricFlow.Infrastructure.Repo
- MetricFlow.Users.Scope
- MetricFlow.DataSync.SyncJob
