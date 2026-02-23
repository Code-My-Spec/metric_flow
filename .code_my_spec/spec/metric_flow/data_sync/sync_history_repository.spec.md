# MetricFlow.DataSync.SyncHistoryRepository

Data access layer for SyncHistory read operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_history/2 with filter options (provider, limit, offset), get_sync_history/2, and create_sync_history/2 functions. Queries ordered by most recent first.

## Functions

### list_sync_history/2

Returns sync history records for the scoped user with optional filtering and pagination, ordered by most recently completed.

```elixir
@spec list_sync_history(Scope.t(), keyword()) :: list(SyncHistory.t())
```

**Process**:
1. Build query filtering by user_id from scope
2. Apply provider filter if provided in options
3. Order by completed_at descending, then id descending
4. Apply limit if provided in options
5. Apply offset if provided in options
6. Execute query with Repo.all()
7. Return list of sync history records (empty list if none exist)

**Test Assertions**:
- Returns all sync history records for scoped user when no options provided
- Returns empty list when no sync history records exist
- Only returns sync history records for scoped user
- Orders by most recently completed first (completed_at desc, id desc)
- Filters by provider when provider option provided
- Returns only :google_analytics sync history when provider: :google_analytics
- Returns only :google_ads sync history when provider: :google_ads
- Returns only :facebook_ads sync history when provider: :facebook_ads
- Returns only :quickbooks sync history when provider: :quickbooks
- Limits results when limit option provided
- Returns exactly 5 records when limit: 5
- Returns exactly 10 records when limit: 10
- Applies offset when offset option provided
- Skips first 5 records when offset: 5
- Skips first 10 records when offset: 10
- Combines limit and offset correctly
- Returns records 6-10 when limit: 5, offset: 5
- Ignores invalid provider values
- Handles empty options keyword list
- Enforces multi-tenant isolation
- Returns sync history with all status values
- Works with multiple filter options combined

### get_sync_history/2

Retrieves a single sync history record for the scoped user by ID.

```elixir
@spec get_sync_history(Scope.t(), integer()) :: {:ok, SyncHistory.t()} | {:error, :not_found}
```

**Process**:
1. Build query filtering by user_id from scope and sync history id
2. Execute query with Repo.one()
3. Return {:error, :not_found} if nil
4. Return {:ok, sync_history} if found

**Test Assertions**:
- Returns sync history when it exists for scoped user
- Returns error when sync history doesn't exist
- Returns error when sync history exists for different user
- Enforces multi-tenant isolation
- Works with any sync history status
- Works with any provider
- Loads association data if preloaded
- Returns complete sync history record with all fields

### create_sync_history/2

Creates a new sync history record for the scoped user.

```elixir
@spec create_sync_history(Scope.t(), map()) :: {:ok, SyncHistory.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Merge user_id from scope into attrs
2. Build changeset with SyncHistory.changeset/2
3. Insert into database with Repo.insert/1
4. Validate provider is supported
5. Validate integration_id references existing integration
6. Validate sync_job_id references existing sync job
7. Validate user_id references existing user
8. Validate required fields (status, started_at, completed_at)
9. Return created sync history or changeset errors

**Test Assertions**:
- Creates sync history with valid attributes
- Returns error with invalid provider
- Returns error with missing required fields
- Returns error with non-existent integration_id
- Returns error with non-existent sync_job_id
- Returns error with non-existent user_id
- Sets user_id from scope automatically
- Creates sync history with :success status
- Creates sync history with :partial_success status
- Creates sync history with :failed status
- Allows optional error_message
- Defaults records_synced to 0 when not provided
- Accepts explicit records_synced value
- Validates records_synced is non-negative
- Returns error with negative records_synced
- Accepts all valid provider enum values
- Accepts all valid status enum values
- Stores started_at timestamp
- Stores completed_at timestamp
- Enforces multi-tenant isolation

## Dependencies

- Ecto.Query
- MetricFlow.Infrastructure.Repo
- MetricFlow.Users.Scope
- MetricFlow.DataSync.SyncHistory
