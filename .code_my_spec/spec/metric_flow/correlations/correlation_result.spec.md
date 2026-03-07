# MetricFlow.Correlations.CorrelationResult

Ecto schema storing a calculated Pearson correlation between a metric and a goal
metric, including the automatically detected optimal time lag. The coefficient
ranges from -1.0 (perfect anti-correlation) to 1.0 (perfect correlation). The
optimal_lag indicates how many days the metric leads the goal metric (0-30). Only
results backed by at least 30 data points are persisted.

## Type

schema

## Fields

| Field               | Type              | Required   | Description                                                                 | Constraints                                                                              |
| ------------------- | ----------------- | ---------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| id                  | integer           | Yes (auto) | Primary key                                                                 | Auto-generated                                                                           |
| account_id          | integer           | Yes        | Owning account foreign key                                                  | References accounts.id                                                                   |
| correlation_job_id  | integer           | Yes        | Job that produced this result                                               | References correlation_jobs.id                                                           |
| metric_name         | string            | Yes        | Name of the input metric being correlated                                   | Max: 255                                                                                 |
| goal_metric_name    | string            | Yes        | Name of the goal metric this was correlated against                         | Max: 255                                                                                 |
| coefficient         | float             | Yes        | Pearson correlation coefficient at the optimal lag                          | -1.0 <= value <= 1.0                                                                     |
| optimal_lag         | integer           | Yes        | Day lag with the highest absolute correlation (lead time of metric_name)   | 0 <= value <= 30                                                                         |
| data_points         | integer           | Yes        | Number of aligned daily data points used in the calculation                | >= 30; results below this threshold are not persisted                                    |
| provider            | enum (atom)       | No         | Source platform of the input metric                                         | One of: google_analytics, google_ads, facebook_ads, quickbooks                          |
| calculated_at       | utc_datetime_usec | Yes        | Timestamp when the correlation was computed                                 |                                                                                          |
| inserted_at         | utc_datetime_usec | Yes (auto) | Record creation timestamp                                                   | Auto-generated                                                                           |
| updated_at          | utc_datetime_usec | Yes (auto) | Record last-update timestamp                                                | Auto-generated                                                                           |

### Unique Constraint

The combination of `(account_id, correlation_job_id, metric_name, goal_metric_name)` is
unique, enforced by a database index. Re-running the same job for the same metric pair
must upsert rather than insert a duplicate row.

### Associations

- `belongs_to :account` — MetricFlow.Accounts.Account. Results are scoped to an account
  and are never shared across accounts.
- `belongs_to :correlation_job` — MetricFlow.Correlations.CorrelationJob. Tracks which
  scheduled or manual job produced this row, enabling auditability and re-run detection.

## Functions

### changeset/2

Casts and validates attributes for creating or updating a CorrelationResult record.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast all permitted fields: account_id, correlation_job_id, metric_name,
   goal_metric_name, coefficient, optimal_lag, data_points, provider, calculated_at
2. Validate required fields: account_id, correlation_job_id, metric_name,
   goal_metric_name, coefficient, optimal_lag, data_points, calculated_at
   (provider is optional — financial metrics have no platform provider)
3. Validate metric_name and goal_metric_name length do not exceed 255 characters
4. Validate coefficient is between -1.0 and 1.0 (inclusive)
5. Validate optimal_lag is between 0 and 30 (inclusive)
6. Validate data_points is >= 30
7. Apply assoc_constraint for account and correlation_job (foreign key integrity)
8. Apply unique_constraint on (account_id, correlation_job_id, metric_name, goal_metric_name)

**Test Assertions**:
- returns a valid changeset for a complete set of valid attributes
- returns an invalid changeset when account_id is missing
- returns an invalid changeset when correlation_job_id is missing
- returns an invalid changeset when metric_name is missing
- returns an invalid changeset when goal_metric_name is missing
- returns an invalid changeset when coefficient is missing
- returns an invalid changeset when optimal_lag is missing
- returns an invalid changeset when data_points is missing
- returns an invalid changeset when calculated_at is missing
- returns a valid changeset when provider is omitted (optional field)
- returns an invalid changeset when metric_name exceeds 255 characters
- returns an invalid changeset when goal_metric_name exceeds 255 characters
- returns an invalid changeset when coefficient is greater than 1.0
- returns an invalid changeset when coefficient is less than -1.0
- returns a valid changeset when coefficient is exactly 1.0
- returns a valid changeset when coefficient is exactly -1.0
- returns an invalid changeset when optimal_lag is negative
- returns an invalid changeset when optimal_lag exceeds 30
- returns a valid changeset when optimal_lag is exactly 0
- returns a valid changeset when optimal_lag is exactly 30
- returns an invalid changeset when data_points is less than 30
- returns a valid changeset when data_points is exactly 30
- returns an invalid changeset for a duplicate (account_id, correlation_job_id, metric_name, goal_metric_name) combination
- returns an invalid changeset when provider is an unrecognised atom

### strong?/1

Returns true when the absolute value of the correlation coefficient is >= 0.7,
indicating a strong linear relationship between the metric and the goal metric.

```elixir
@spec strong?(t()) :: boolean()
```

**Process**:
1. Take the absolute value of the result's coefficient
2. Return true if abs(coefficient) >= 0.7, otherwise return false

**Test Assertions**:
- returns true when coefficient is 0.7 (boundary — strong threshold)
- returns true when coefficient is 1.0 (perfect positive correlation)
- returns true when coefficient is -0.7 (boundary — negative strong)
- returns true when coefficient is -1.0 (perfect negative correlation)
- returns false when coefficient is 0.69 (just below threshold)
- returns false when coefficient is 0.0 (no correlation)
- returns false when coefficient is -0.69 (just below negative threshold)

### strength_label/1

Returns a human-readable string describing the correlation strength based on
established thresholds applied to the absolute coefficient value.

```elixir
@spec strength_label(t()) :: String.t()
```

**Process**:
1. Take the absolute value of the result's coefficient
2. Return "Strong" if abs(coefficient) >= 0.7
3. Return "Moderate" if abs(coefficient) >= 0.4
4. Return "Weak" if abs(coefficient) >= 0.2
5. Return "Negligible" for all other values (abs(coefficient) < 0.2)

**Test Assertions**:
- returns "Strong" when coefficient is 0.7 (lower boundary)
- returns "Strong" when coefficient is 1.0
- returns "Strong" when coefficient is -0.85
- returns "Moderate" when coefficient is 0.4 (lower boundary)
- returns "Moderate" when coefficient is 0.69 (upper boundary of moderate)
- returns "Moderate" when coefficient is -0.55
- returns "Weak" when coefficient is 0.2 (lower boundary)
- returns "Weak" when coefficient is 0.39
- returns "Weak" when coefficient is -0.3
- returns "Negligible" when coefficient is 0.19 (just below weak threshold)
- returns "Negligible" when coefficient is 0.0
- returns "Negligible" when coefficient is -0.1

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
- MetricFlow.Correlations.CorrelationJob
