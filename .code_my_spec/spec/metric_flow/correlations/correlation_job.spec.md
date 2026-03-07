# MetricFlow.Correlations.CorrelationJob

Ecto schema representing a scheduled or completed correlation calculation run. Tracks the
lifecycle of a background Oban job that computes Pearson correlations with time-lagged
cross-correlation (TLCC) between all metrics and a selected goal metric. Scoped to an
Account.

## Type

schema

## Fields

| Field              | Type              | Required   | Description                                                             | Constraints                          |
| ------------------ | ----------------- | ---------- | ----------------------------------------------------------------------- | ------------------------------------ |
| id                 | integer           | Yes (auto) | Primary key                                                             | Auto-generated                       |
| account_id         | integer           | Yes        | Foreign key to the owning account                                       | References accounts.id               |
| status             | atom (enum)       | Yes        | Current lifecycle state of the job                                      | One of: pending, running, completed, failed; default: pending |
| goal_metric_name   | string            | Yes        | Name of the metric being used as the correlation target                 | Max: 255                             |
| data_window_start  | date              | No         | Earliest date of metric data included in this calculation               |                                      |
| data_window_end    | date              | No         | Latest date of metric data included in this calculation                 |                                      |
| data_points        | integer           | No         | Number of daily data points available across the window                 | >= 0                                 |
| results_count      | integer           | No         | Number of correlation results produced by this job                      | >= 0                                 |
| started_at         | utc_datetime_usec | No         | Timestamp when the Oban worker began executing the job                  |                                      |
| completed_at       | utc_datetime_usec | No         | Timestamp when the job finished (successfully or with failure)          |                                      |
| error_message      | string            | No         | Human-readable description of the failure reason, when status = failed  |                                      |
| inserted_at        | utc_datetime_usec | Yes (auto) | Record creation timestamp                                               | Auto-generated                       |
| updated_at         | utc_datetime_usec | Yes (auto) | Record last-update timestamp                                            | Auto-generated                       |

### Status Transitions

```
:pending -> :running    (Oban worker picks up the job)
:running -> :completed  (all correlations calculated successfully)
:running -> :failed     (calculation error or timeout)
```

Only `started_at` is set on the `:pending -> :running` transition. Both `completed_at`
and either `results_count` or `error_message` are set on the terminal transitions.

## Functions

### changeset/2

Casts and validates attributes for creating or updating a CorrelationJob record.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast all permitted fields: `account_id`, `status`, `goal_metric_name`, `data_window_start`, `data_window_end`, `data_points`, `results_count`, `started_at`, `completed_at`, `error_message`
2. Validate that `account_id`, `status`, and `goal_metric_name` are present
3. Validate `goal_metric_name` length does not exceed 255 characters
4. Validate `data_points` is greater than or equal to 0
5. Validate `results_count` is greater than or equal to 0
6. Add an association constraint ensuring `account_id` references an existing account

**Test Assertions**:
- returns a valid changeset when all required fields are provided
- returns an invalid changeset when `account_id` is missing
- returns an invalid changeset when `status` is missing
- returns an invalid changeset when `goal_metric_name` is missing
- returns an invalid changeset when `goal_metric_name` exceeds 255 characters
- returns an invalid changeset when `data_points` is negative
- returns an invalid changeset when `results_count` is negative
- defaults `status` to `:pending` when not provided

### running?/1

Returns true when the job's current status is `:running`.

```elixir
@spec running?(t()) :: boolean()
```

**Process**:
1. Pattern-match on the struct's `status` field
2. Return `true` when status is `:running`, `false` for all other statuses

**Test Assertions**:
- returns true for a job with status `:running`
- returns false for a job with status `:pending`
- returns false for a job with status `:completed`
- returns false for a job with status `:failed`

### completed?/1

Returns true when the job's current status is `:completed`.

```elixir
@spec completed?(t()) :: boolean()
```

**Process**:
1. Pattern-match on the struct's `status` field
2. Return `true` when status is `:completed`, `false` for all other statuses

**Test Assertions**:
- returns true for a job with status `:completed`
- returns false for a job with status `:pending`
- returns false for a job with status `:running`
- returns false for a job with status `:failed`

### duration/1

Returns the elapsed seconds between `started_at` and `completed_at`. When
`completed_at` is nil (job still running), uses the current UTC time as the
end point. Returns nil when `started_at` has not been set.

```elixir
@spec duration(t()) :: integer() | nil
```

**Process**:
1. If `started_at` is nil, return nil immediately
2. If `completed_at` is set, compute `DateTime.diff(completed_at, started_at, :second)`
3. If `completed_at` is nil, compute `DateTime.diff(DateTime.utc_now(), started_at, :second)`

**Test Assertions**:
- returns nil when `started_at` is nil
- returns the correct second difference when both `started_at` and `completed_at` are set
- returns a positive integer based on the current time when `completed_at` is nil and `started_at` is set
- returns 0 when `started_at` and `completed_at` are identical timestamps

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
