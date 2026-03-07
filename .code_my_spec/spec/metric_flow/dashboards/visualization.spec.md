# MetricFlow.Dashboards.Visualization

Standalone Vega-Lite spec with name, owner (user_id), raw vega_spec JSON map, and a shareable flag. A single Visualization may be referenced by many dashboards via the DashboardVisualization join schema, enabling reuse across dashboard collections without duplication. The owning user is referenced via a `belongs_to :user` association enforced by `assoc_constraint/2`. Dashboard membership is expressed through a `has_many :dashboard_visualizations` join.

## Type

schema

## Fields

| Field                  | Type              | Required   | Description                                                              | Constraints                              |
| ---------------------- | ----------------- | ---------- | ------------------------------------------------------------------------ | ---------------------------------------- |
| id                     | integer           | Yes (auto) | Primary key                                                              | Auto-generated                           |
| name                   | string            | Yes        | Human-readable display name for the visualization                        | Min: 1, Max: 255                         |
| user_id                | integer           | Yes        | Foreign key referencing the owning user (belongs_to :user)               | References users.id                      |
| vega_spec              | map               | Yes        | Raw Vega-Lite JSON specification stored as a JSONB map                   | Must be a valid Elixir map               |
| shareable              | boolean           | No         | Controls whether other users may access this visualization               | Defaults to false                        |
| inserted_at            | utc_datetime_usec | Yes (auto) | Insertion timestamp                                                      | Auto-generated                           |
| updated_at             | utc_datetime_usec | Yes (auto) | Last update timestamp                                                    | Auto-generated                           |

## Functions

### changeset/2

Creates or updates an Ecto changeset for a Visualization record.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the permitted fields: `name`, `user_id`, `vega_spec`, `shareable`
2. Validate that `name`, `user_id`, and `vega_spec` are present (required)
3. Validate `name` length is between 1 and 255 characters inclusive
4. Add an `assoc_constraint` on `:user` so that inserting a record with a non-existent `user_id` returns `{:error, changeset}` with a `user: ["does not exist"]` error rather than a raw database exception

**Test Assertions**:
- creates a valid changeset when all required fields are provided
- casts `name`, `user_id`, `vega_spec`, and `shareable` correctly into changeset changes
- returns an invalid changeset when `name` is absent
- returns an invalid changeset when `user_id` is absent
- returns an invalid changeset when `vega_spec` is absent
- rejects an empty string for `name` (below minimum length of 1)
- rejects a `name` longer than 255 characters
- accepts a `name` of exactly 1 character (minimum boundary)
- accepts a `name` of exactly 255 characters (maximum boundary)
- defaults `shareable` to false when not provided in attrs
- accepts `shareable: true` explicitly
- accepts `shareable: false` explicitly
- accepts any valid Elixir map for `vega_spec` (including empty map and nested maps)
- triggers `assoc_constraint` error on insert when `user_id` references a non-existent user
- produces a valid changeset when updating an existing visualization with a subset of fields
- preserves existing field values on the changeset struct when only a subset of attributes are updated
- handles an empty attributes map gracefully without marking the changeset invalid

### shareable?/1

Returns whether the visualization is marked as shareable.

```elixir
@spec shareable?(t()) :: boolean()
```

**Process**:
1. Pattern-match the struct: if `shareable` is exactly `true`, return `true`
2. For any other value (including `false` and `nil`), return `false`

**Test Assertions**:
- returns `true` when `shareable` is `true`
- returns `false` when `shareable` is `false`
- returns `false` when `shareable` is `nil` (field unset)
- returns the correct result when the struct also has a populated `vega_spec` map
- returns `false` for a visualization with no dashboard associations loaded

## Dependencies

- MetricFlow.Users.User
- MetricFlow.Dashboards.DashboardVisualization
