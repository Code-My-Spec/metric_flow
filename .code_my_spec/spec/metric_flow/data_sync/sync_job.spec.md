# MetricFlow.DataSync.SyncJob

Ecto schema representing scheduled or running sync jobs. Stores user_id, integration_id, provider, status (pending, running, completed, failed, cancelled), started_at, and completed_at timestamps. Belongs to User and Integration. Provides status transition functions and running time calculations.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| user_id | integer | Yes | Foreign key to users table | References MetricFlow.Users.User |
| integration_id | integer | Yes | Foreign key to integrations table | References MetricFlow.Integrations.Integration |
| provider | Ecto.Enum | Yes | The external service provider | Must be one of: :google_analytics, :google_ads, :facebook_ads, :quickbooks |
| status | Ecto.Enum | Yes | Current state of the sync job | Must be one of: :pending, :running, :completed, :failed, :cancelled. Defaults to :pending |
| started_at | utc_datetime_usec | No | UTC timestamp when job started running | Set when status transitions to :running |
| completed_at | utc_datetime_usec | No | UTC timestamp when job finished | Set when status transitions to :completed, :failed, or :cancelled |
| error_message | string | No | Error details when sync fails | Only populated when status is :failed |
| inserted_at | utc_datetime_usec | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime_usec | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a SyncJob record. Validates all required fields, type constraints, associations, and ensures provider enum values are valid.

```elixir
@spec changeset(SyncJob.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: user_id, integration_id, provider, status, started_at, completed_at, error_message
2. Validate required fields: user_id, integration_id, provider, status
3. Add association constraint on user (ensures referenced user exists)
4. Add association constraint on integration (ensures referenced integration exists)
5. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts each field attribute correctly (user_id, integration_id, provider, status, started_at, completed_at, error_message)
- Validates user_id is required
- Validates integration_id is required
- Validates provider is required
- Validates status is required
- Allows nil started_at as optional
- Allows nil completed_at as optional
- Allows nil error_message as optional
- Accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)
- Accepts all valid status enum values (:pending, :running, :completed, :failed, :cancelled)
- Validates user association exists (assoc_constraint triggers on insert)
- Validates integration association exists (assoc_constraint triggers on insert)
- Defaults status to :pending when not provided
- Creates valid changeset for updating existing sync job
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

### running?/1

Checks if the sync job is currently in running state.

```elixir
@spec running?(SyncJob.t()) :: boolean()
```

**Process**:
1. Pattern match on sync_job.status
2. Return true if status is :running
3. Return false for any other status

**Test Assertions**:
- Returns true when status is :running
- Returns false when status is :pending
- Returns false when status is :completed
- Returns false when status is :failed
- Returns false when status is :cancelled
- Works with sync job that has started_at timestamp
- Works with sync job that has no started_at timestamp

### completed?/1

Checks if the sync job has finished execution (successfully or unsuccessfully).

```elixir
@spec completed?(SyncJob.t()) :: boolean()
```

**Process**:
1. Pattern match on sync_job.status
2. Return true if status is :completed
3. Return false for any other status

**Test Assertions**:
- Returns true when status is :completed
- Returns false when status is :pending
- Returns false when status is :running
- Returns false when status is :failed
- Returns false when status is :cancelled
- Works with sync job that has completed_at timestamp
- Works with sync job that has no completed_at timestamp

### running_time/1

Calculates the duration of the sync job execution. Returns time between started_at and completed_at for finished jobs, or time between started_at and current time for running jobs.

```elixir
@spec running_time(SyncJob.t()) :: integer() | nil
```

**Process**:
1. Check if sync_job.started_at is nil
2. Return nil if no started_at timestamp (job hasn't started)
3. If completed_at is present, calculate difference between completed_at and started_at in seconds
4. If completed_at is nil, calculate difference between current UTC time and started_at in seconds
5. Return integer representing seconds elapsed

**Test Assertions**:
- Returns nil when started_at is nil
- Returns nil when status is :pending and no started_at
- Returns duration in seconds when job is completed
- Returns duration in seconds when job is failed
- Returns duration in seconds when job is cancelled
- Returns elapsed time in seconds when job is running (no completed_at)
- Calculates duration using DateTime.diff/2 with :second unit
- Returns positive integer for valid time ranges
- Returns 0 when started_at equals completed_at
- Uses current UTC time for running jobs without completed_at
- Works with utc_datetime_usec precision

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Users.User
- MetricFlow.Integrations.Integration
- DateTime
