# MetricFlow.Metrics.Metric

Ecto schema representing a unified metric data point. Stores metric_type (category like "traffic", "advertising", "financial"), metric_name (specific metric like "sessions", "clicks", "revenue"), value as float, recorded_at timestamp, provider atom matching Integration provider enum, and dimensions as embedded map for dimension breakdowns (source, campaign, page, etc.). Belongs to User. Indexed on [user_id, provider], [user_id, metric_name, recorded_at], and [user_id, metric_type].

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| metric_type | string | Yes | High-level category of the metric | Examples: "traffic", "advertising", "financial" |
| metric_name | string | Yes | Specific metric identifier within its type | Examples: "sessions", "clicks", "revenue" |
| value | float | Yes | The numeric measurement for this data point | Must be a valid float |
| recorded_at | utc_datetime_usec | Yes | UTC timestamp when the metric was observed | Must be a valid UTC datetime |
| provider | Ecto.Enum | Yes | The external platform that produced this metric | Must be one of: :google_analytics, :google_ads, :facebook_ads, :quickbooks |
| dimensions | map | No | Key/value breakdown dimensions for the data point (source, campaign, page, etc.) | Defaults to empty map, must be a map type |
| user_id | integer | Yes | Foreign key to users table | References MetricFlow.Users.User |
| inserted_at | utc_datetime_usec | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime_usec | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a Metric record. Validates all required fields and type constraints and enforces the association constraint on user.

```elixir
@spec changeset(Metric.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: user_id, metric_type, metric_name, value, recorded_at, provider, dimensions
2. Validate required fields: user_id, metric_type, metric_name, value, recorded_at, provider
3. Validate dimensions is a map when present
4. Add association constraint on user (ensures referenced user exists)
5. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts each field attribute correctly (user_id, metric_type, metric_name, value, recorded_at, provider, dimensions)
- Validates user_id is required
- Validates metric_type is required
- Validates metric_name is required
- Validates value is required
- Validates recorded_at is required
- Validates provider is required
- Accepts all valid provider enum values (:google_analytics, :google_ads, :facebook_ads, :quickbooks)
- Rejects unknown provider values
- Allows nil dimensions (defaults to empty map)
- Validates dimensions is a map when provided
- Rejects dimensions when not a map
- Rejects dimensions when it is a list
- Validates user association exists (assoc_constraint triggers on insert)
- Creates valid changeset for updating existing metric
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully
- Accepts float value with decimal precision
- Accepts integer value coerced to float

## Delegates

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Users.User
