# MetricFlow.Correlations

Public API boundary for the Correlations bounded context.

Computes Pearson correlation coefficients with time-lagged cross-correlation (TLCC) between marketing and financial metrics and user-selected goal metrics. Orchestrates background correlation jobs via Oban, stores results, and exposes query functions for the CorrelationLive views.

All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Delegates

- list_correlation_results/2: MetricFlow.Correlations.CorrelationsRepository.list_correlation_results/2
- get_correlation_result/2: MetricFlow.Correlations.CorrelationsRepository.get_correlation_result/2
- get_correlation_job/2: MetricFlow.Correlations.CorrelationsRepository.get_correlation_job/2
- list_correlation_jobs/1: MetricFlow.Correlations.CorrelationsRepository.list_correlation_jobs/1

## Functions

### run_correlations/2

Triggers a correlation calculation job for the scoped user's metrics. Creates a CorrelationJob record and enqueues a CorrelationWorker via Oban. Returns `:already_running` when a pending or running job already exists for the user, and `:insufficient_data` when fewer than two distinct metrics are available.

```elixir
@spec run_correlations(Scope.t(), map()) ::
        {:ok, CorrelationJob.t()} | {:error, :insufficient_data} | {:error, :already_running}
```

**Process**:
1. Check whether a pending or running CorrelationJob already exists for the scope — return `{:error, :already_running}` if so
2. Check whether at least two distinct metric names exist for the scope via `Metrics.list_metric_names/1` — return `{:error, :insufficient_data}` if fewer than two are found
3. Extract `goal_metric_name` from attrs (supports both atom and string keys)
4. Create a CorrelationJob record via `CorrelationsRepository.create_correlation_job/2` with status `:pending` and the resolved goal metric name
5. Enqueue a `CorrelationWorker` Oban job with `%{job_id: job.id, user_id: scope.user.id}`
6. Return `{:ok, job}`

**Test Assertions**:
- returns `{:ok, %CorrelationJob{}}` when the user has sufficient data and no running job
- created job has status `:pending`
- stores goal_metric_name in the job record
- enqueues an Oban CorrelationWorker job with correct job_id and user_id args
- returns `{:error, :insufficient_data}` when the user has fewer than two distinct metrics
- returns `{:error, :already_running}` when a job with status `:running` already exists for the user
- returns `{:error, :already_running}` when a job with status `:pending` already exists for the user

### schedule_daily_correlations/0

Schedules correlation recalculation for all users who have active integrations and sufficient metric data. Called by Oban cron after the daily data sync completes. Skips users whose most recent completed correlation job finished within the last 24 hours.

```elixir
@spec schedule_daily_correlations() :: {:ok, integer()}
```

**Process**:
1. Retrieve all active integrations via `Integrations.list_all_active_integrations/0` and collect unique user IDs
2. Build a `%Scope{}` for each user via `Scope.for_user/1`
3. Filter scopes to only those that are schedulable: have at least two distinct metric names and do not have a completed job within the last 24 hours
4. For each schedulable scope, determine the goal metric: reuse the goal from the most recent completed job, or fall back to the first metric name, or default to `"revenue"` if no metrics exist
5. Call `create_and_enqueue/2` for each schedulable scope with the resolved goal metric
6. Return `{:ok, count}` where count is the number of successfully enqueued jobs

**Test Assertions**:
- schedules jobs for users with at least two distinct metrics and active integrations
- skips users with fewer than two distinct metrics
- skips users whose most recent completed job was completed within the last 24 hours
- enqueues a CorrelationWorker Oban job for each eligible user
- returns `{:ok, count}` with the correct count of scheduled jobs
- returns `{:ok, 0}` when no users are eligible

### get_latest_correlation_summary/1

Returns a summary map of the most recent correlation results for the scoped user, suitable for display in the CorrelationLive views. When no completed job exists, returns a summary with empty results and `no_data: true`.

```elixir
@spec get_latest_correlation_summary(Scope.t()) :: map()
```

**Process**:
1. Fetch the most recent completed CorrelationJob for the scope via `CorrelationsRepository.get_latest_completed_job/1`
2. If no completed job exists, return `%{results: [], goal_metric_name: nil, last_calculated_at: nil, data_window: nil, data_points_count: nil, no_data: true}`
3. If a completed job is found, call `CorrelationsRepository.list_correlation_results/2` to retrieve all results for the scope
4. Return `%{results: results, goal_metric_name: job.goal_metric_name, last_calculated_at: job.completed_at, data_window: {job.data_window_start, job.data_window_end}, data_points_count: job.data_points, no_data: false}`

**Test Assertions**:
- returns a map with results sorted by absolute coefficient descending (strongest correlation first)
- includes `last_calculated_at` matching the completed job's `completed_at` timestamp
- includes `data_window` as a `{start_date, end_date}` tuple from the job record
- includes `data_points_count` matching the job's `data_points` field
- includes `goal_metric_name` from the job record
- returns `no_data: true` with empty results when no completed job exists
- returns `last_calculated_at: nil` when no completed job exists
- does not return results belonging to another user's scope

## Dependencies

- MetricFlow.Metrics
- MetricFlow.Integrations
- MetricFlow.Users.Scope

## Components

### MetricFlow.Correlations.CorrelationJob

Ecto schema representing a scheduled or in-progress correlation calculation. Tracks the job status (`:pending`, `:running`, `:completed`, `:failed`), the goal metric name, the data window dates, the number of data points used, and the completion timestamp. Scoped to a user via `user_id`.

### MetricFlow.Correlations.CorrelationResult

Ecto schema representing a single calculated correlation between a metric and the goal metric. Stores the metric name, goal metric name, Pearson coefficient, optimal lag in days, number of data points, the calculation timestamp, and a foreign key to the parent CorrelationJob.

### MetricFlow.Correlations.CorrelationsRepository

Data access layer for CorrelationJob and CorrelationResult persistence. Handles all Repo interactions including scoped queries, creation, and status checks. Enforces user-scoped isolation on all read operations.

### MetricFlow.Correlations.CorrelationWorker

Oban worker that performs the actual correlation calculations for a single user. Accepts `%{"job_id" => id, "user_id" => id}` as job args. Reads metric time series data, invokes `Math.cross_correlate/3` for each metric pair against the goal metric, persists results as CorrelationResult records, and updates the CorrelationJob status to `:completed` or `:failed`.

### MetricFlow.Correlations.Math

Pure functional module implementing statistical calculations. Provides `pearson/2` (Pearson correlation coefficient from two float lists), `cross_correlate/3` (time-lagged cross-correlation testing lags 0 to 30, returning the optimal lag and coefficient), and `extract_values/2` (converts metric time series to aligned float lists). Has no external dependencies.

