# MetricFlow.Dashboards.Dashboard

Named collection of visualizations owned by a user. A dashboard aggregates one or more Visualizations via the DashboardVisualization junction and carries a `built_in` flag that distinguishes system-provided canned dashboards from user-created ones. Canned dashboards are seeded by the application and should not be modified by users.

## Type

schema

## Fields

| Field                    | Type                          | Required   | Description                                                                      | Constraints                              |
| ------------------------ | ----------------------------- | ---------- | -------------------------------------------------------------------------------- | ---------------------------------------- |
| id                       | integer                       | Yes (auto) | Primary key                                                                      | Auto-generated                           |
| name                     | string                        | Yes        | Human-readable label for the dashboard                                           | Min: 1, Max: 255                         |
| description              | string                        | No         | Optional longer description of the dashboard's purpose                           | Max: 1000                                |
| built_in                 | boolean                       | No         | True for system-provided canned dashboards; false for user-created dashboards    | Default: false                           |
| user_id                  | integer                       | Yes        | Foreign key to the owning user                                                   | References users.id                      |
| user                     | association (User)            | No         | Belongs-to association for the owning user; loaded on demand                     | assoc_constraint enforced on insert      |
| dashboard_visualizations | association (list)            | No         | Has-many DashboardVisualization junction records; loaded on demand               |                                          |
| visualizations           | association (list, through)   | No         | Through-association to Visualization records via dashboard_visualizations        |                                          |
| inserted_at              | utc_datetime_usec             | Yes (auto) | Record creation timestamp                                                        | Auto-generated                           |
| updated_at               | utc_datetime_usec             | Yes (auto) | Record last-update timestamp                                                     | Auto-generated                           |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a Dashboard record.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the `name`, `description`, `user_id`, and `built_in` fields from the given attrs map
2. Validate that `name` and `user_id` are present and non-blank
3. Validate that `name` is between 1 and 255 characters inclusive
4. Validate that `description` does not exceed 1000 characters when provided
5. Add an association constraint on `user` so that inserting a changeset with a non-existent `user_id` produces a human-readable error rather than a raw database exception

**Test Assertions**:
- returns a valid changeset when all required fields are present
- casts name correctly
- casts description correctly
- casts user_id correctly
- casts built_in correctly when set to true
- returns an invalid changeset and adds a name error when name is absent
- returns an invalid changeset and adds a user_id error when user_id is absent
- returns an invalid changeset when name is an empty string
- returns an invalid changeset when name exceeds 255 characters
- returns a valid changeset when name is exactly 1 character
- returns a valid changeset when name is exactly 255 characters
- returns an invalid changeset when description exceeds 1000 characters
- returns a valid changeset when description is exactly 1000 characters
- returns a valid changeset when description is nil (optional field)
- defaults built_in to false when omitted from attrs (enforced at the database level)
- accepts built_in true for system dashboards
- accepts built_in false for user-created dashboards
- triggers the user assoc_constraint and surfaces "does not exist" error on insert with a non-existent user_id
- returns a valid changeset when updating an existing dashboard with a subset of fields
- preserves existing field values on the changeset data when only one field is updated
- returns a valid changeset when attrs is an empty map and the struct already has required fields

### built_in?/1

Returns true if the dashboard is a system-provided canned dashboard; false otherwise.

```elixir
@spec built_in?(t()) :: boolean()
```

**Process**:
1. Pattern-match on `built_in: true`; return `true` if matched
2. Fall through for any other `Dashboard` struct and return `false`

**Test Assertions**:
- returns true when built_in is true
- returns false when built_in is false
- returns false for a persisted dashboard that was inserted without explicitly setting built_in (default false)

## Dependencies

- MetricFlow.Dashboards.DashboardVisualization
- MetricFlow.Dashboards.Visualization
- MetricFlow.Users.User
