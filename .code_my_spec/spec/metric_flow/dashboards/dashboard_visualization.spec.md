# MetricFlow.Dashboards.DashboardVisualization

Junction table linking a Dashboard to a Visualization with layout metadata (position and size). A given visualization may only appear once per dashboard, enforced by a unique database constraint on the `{dashboard_id, visualization_id}` pair.

## Type

module

## Fields

| Field            | Type     | Required   | Description                                              | Constraints                                                                 |
| ---------------- | -------- | ---------- | -------------------------------------------------------- | --------------------------------------------------------------------------- |
| id               | integer  | Yes (auto) | Primary key                                              | Auto-generated                                                              |
| dashboard_id     | integer  | Yes        | Foreign key to the owning dashboard                      | References dashboards.id; assoc_constraint enforced                         |
| visualization_id | integer  | Yes        | Foreign key to the visualization being placed            | References visualizations.id; assoc_constraint enforced                     |
| position         | integer  | Yes        | Display order within the dashboard (0-based, ascending)  | Must be >= 0                                                                |
| size             | string   | No         | Layout hint controlling rendered width of the tile       | Default: "medium"; one of "small", "medium", "large", "full"                |
| inserted_at      | datetime | Yes (auto) | Record creation timestamp                                | Auto-generated (utc_datetime_usec)                                          |
| updated_at       | datetime | Yes (auto) | Record last-updated timestamp                            | Auto-generated (utc_datetime_usec)                                          |

## Functions

### changeset/2

Creates an Ecto changeset for inserting or updating a DashboardVisualization record. Casts all permitted fields, enforces required fields, validates position is non-negative, validates size is within the permitted set, enforces association existence, and enforces the unique pair constraint.

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast `dashboard_id`, `visualization_id`, `position`, and `size` from the given attrs map
2. Validate that `dashboard_id`, `visualization_id`, and `position` are present (required)
3. Validate that `position` is greater than or equal to 0
4. Validate that `size`, when provided, is one of the allowed values: "small", "medium", "large", "full"
5. Apply `assoc_constraint` on `:dashboard` so an invalid `dashboard_id` surfaces as an association error on insert
6. Apply `assoc_constraint` on `:visualization` so an invalid `visualization_id` surfaces as an association error on insert
7. Apply `unique_constraint` on `[:dashboard_id, :visualization_id]` using the named index `dashboard_visualizations_dashboard_id_visualization_id_index`

**Test Assertions**:
- returns a valid changeset when all required fields are present
- defaults size to "medium" when size is omitted and the record is inserted
- casts `dashboard_id` correctly into the changeset
- casts `visualization_id` correctly into the changeset
- casts `position` correctly into the changeset
- casts `size` correctly into the changeset
- returns an invalid changeset when `dashboard_id` is missing
- returns an invalid changeset when `visualization_id` is missing
- returns an invalid changeset when `position` is missing
- accepts size as optional (omitting it still produces a valid changeset)
- accepts 0 as a valid position value
- accepts positive integers for position
- rejects negative integers for position
- accepts "small" as a valid size value
- accepts "medium" as a valid size value
- accepts "large" as a valid size value
- accepts "full" as a valid size value
- rejects size values outside the permitted set (e.g. "gigantic")
- returns an association error on insert when `dashboard_id` does not reference an existing dashboard
- returns an association error on insert when `visualization_id` does not reference an existing visualization
- returns a unique constraint error on insert when the same `{dashboard_id, visualization_id}` pair already exists
- returns a valid changeset for updating mutable fields (position, size) on an existing record
- preserves existing field values when only a subset of attributes is updated
- handles an empty attributes map gracefully when called on a persisted record

## Dependencies

- MetricFlow.Dashboards.Dashboard
- MetricFlow.Dashboards.Visualization
