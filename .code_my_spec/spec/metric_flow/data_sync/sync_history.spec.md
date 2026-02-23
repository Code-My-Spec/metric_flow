# MetricFlow.DataSync.SyncHistory

Ecto schema representing completed sync records with outcome tracking. Stores user_id, integration_id, provider, status (success, partial_success, failed), records_synced count, error messages, started_at, and completed_at timestamps. Belongs to User and Integration. Provides success rate queries and error analysis functions.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| user_id | integer | Yes | Foreign key to users table | References MetricFlow.Users.User |
| integration_id | integer | Yes | Foreign key to integrations table | References MetricFlow.Integrations.Integration |
| sync_job_id | integer | Yes | Foreign key to sync_jobs table | References MetricFlow.DataSync.SyncJob |
| provider | Ecto.Enum | Yes | The external service provider | Must be one of: :google_analytics, :google_ads, :facebook_ads, :quickbooks |
| status | Ecto.Enum | Yes | Outcome of the sync operation | Must be one of: :success, :partial_success, :failed |
| records_synced | integer | Yes | Number of records successfully synced | Must be >= 0, defaults to 0 |
| error_message | string | No | Error details when sync fails or partially succeeds | Populated when status is :failed or :partial_success |
| started_at | utc_datetime_usec | Yes | UTC timestamp when the sync started | Must be a valid UTC datetime |
| completed_at | utc_datetime_usec | Yes | UTC timestamp when the sync finished | Must be a valid UTC datetime |
| inserted_at | utc_datetime_usec | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime_usec | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a SyncHistory record. Validates all required fields, type constraints, associations, and ensures records_synced is non-negative.

```elixir
@spec changeset(SyncHistory.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: user_id, integration_id, sync_job_id, provider, status, records_synced, error_message, started_at, completed_at
2. Validate required fields: user_id, integration_id, sync_job_id, provider, status, records_synced, started_at, completed_at
3. Validate records_synced is >= 0 using validate_number
4. Add association constraint on user (ensures referenced user exists)
5. Add association constraint on integration (ensures referenced integration exists)
6. Add association constraint on sync_job (ensures referenced sync job exists)
7. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts each field attribute correctly (user_id, integration_id, sync_job_id, provider, status, records_synced, error_message, started_at, completed_at)
- Validates user_id is required
- Validates integration_id is required
- Validates sync_job_id is required
- Validates provider is required
- Validates status is required
- Validates records_synced is required
- Validates started_at is required
- Validates completed_at is required
- Allows nil error_message as optional
- Defaults records_synced to 0 when not provided
- Validates records_synced is >= 0
- Rejects negative values for records_synced
- Accepts 0 for records_synced
- Accepts positive integers for records_synced
- Accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)
- Accepts all valid status enum values (:success, :partial_success, :failed)
- Validates user association exists (assoc_constraint triggers on insert)
- Validates integration association exists (assoc_constraint triggers on insert)
- Validates sync_job association exists (assoc_constraint triggers on insert)
- Creates valid changeset for updating existing sync history
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

### success?/1

Checks if the sync operation completed successfully.

```elixir
@spec success?(SyncHistory.t()) :: boolean()
```

**Process**:
1. Pattern match on sync_history.status
2. Return true if status is :success
3. Return false for any other status (:partial_success, :failed)

**Test Assertions**:
- Returns true when status is :success
- Returns false when status is :partial_success
- Returns false when status is :failed
- Works with sync history that has records_synced > 0
- Works with sync history that has records_synced = 0
- Works with sync history that has error_message
- Works with sync history that has no error_message

### duration/1

Calculates the duration of the sync operation in seconds between started_at and completed_at.

```elixir
@spec duration(SyncHistory.t()) :: integer()
```

**Process**:
1. Get sync_history.started_at timestamp
2. Get sync_history.completed_at timestamp
3. Calculate difference between completed_at and started_at using DateTime.diff/2 with :second unit
4. Return integer representing seconds elapsed

**Test Assertions**:
- Returns duration in seconds between started_at and completed_at
- Returns positive integer for successful sync
- Returns positive integer for failed sync
- Returns positive integer for partially successful sync
- Calculates duration using DateTime.diff/2 with :second unit
- Returns 0 when started_at equals completed_at
- Returns correct duration for sync lasting one second
- Returns correct duration for sync lasting one minute
- Returns correct duration for sync lasting one hour
- Works with utc_datetime_usec precision
- Works with different providers
- Works with different status values

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Users.User
- MetricFlow.Integrations.Integration
- MetricFlow.DataSync.SyncJob
- DateTime
