# MetricFlowWeb.CorrelationLive.Goals

Configure goal metrics. Allows an authenticated user to select which metric serves as the goal metric against which all other metrics are correlated by the correlation engine.

## Type

liveview

## Route

`/correlations/goals`

## Params

None

## Dependencies

- MetricFlow.Metrics
- MetricFlow.Correlations

## User Interactions

- **phx-change="select_goal"**: Fires when the user changes the goal metric dropdown selection. Updates `selected_goal` assign with the chosen metric name string. Calls no context function — client-side assign update only.
- **phx-submit="save_goal"**: Validates that `selected_goal` is non-empty and present in `metric_names`. Calls `Correlations.run_correlations/2` with the selected goal metric name as `%{goal_metric_name: selected_goal}`. On `{:ok, _job}` flashes an info message "Goal metric saved. Correlation analysis started." and redirects to `/correlations`. On `{:error, :already_running}` flashes an info message "A correlation run is already in progress." and redirects to `/correlations`. On `{:error, :insufficient_data}` flashes an error message "Not enough data — at least 30 days of metrics required." and stays on the page with the form still visible. When `selected_goal` is empty, flashes an error "Please select a goal metric." and stays on the page.
- **phx-click="cancel"**: Navigates back to `/correlations` without saving. No context function called.

## Components

None

## Design

Layout: Centered single-column page, `max-w-2xl mx-auto`, `.mf-content` wrapper for z-index above the aurora background. Padding `px-4 py-8`.

On mount, calls `Metrics.list_metric_names/1` to load `metric_names` as a list of distinct metric name strings for the dropdown. Calls `Correlations.get_latest_correlation_summary/1` to determine the current `selected_goal` — pre-selected to `summary.goal_metric_name` when non-nil, otherwise defaults to the first entry in `metric_names`, otherwise empty string. Default assigns: `metric_names: list(String.t())`, `selected_goal: String.t()`. Unauthenticated requests are redirected to `/users/log-in` by the router plug. All context calls are scoped to `current_scope` for multi-tenant isolation.

### Page header

H1 "Goal Metric" with muted subtitle "Choose the metric the correlation engine targets."

### Goal metric form

A `<.form>` with `phx-submit="save_goal"` wrapping a `.mf-card p-6` card.

Form body:
- `.form-control` with label "Goal Metric" and a `<select>` element using `phx-change="select_goal"`. The select has one `<option>` per entry in `metric_names`, with the option whose value matches `selected_goal` marked as selected. When `metric_names` is empty a disabled placeholder option "No metrics available — sync data first" is shown. The select uses `.select select-bordered w-full` classes.
- When `metric_names` is empty the submit button is disabled.

Form footer (flex row, `gap-2 mt-6`):
- Save Goal button: `.btn btn-primary` (`data-role="save-goal"`), disabled when `metric_names` is empty.
- Cancel button: `.btn btn-ghost` (`data-role="cancel"`), `phx-click="cancel"`.

### Empty state

When `metric_names` is empty the card body shows a muted paragraph "No metrics available. Connect your integrations and sync data before configuring a goal." with a `<.link navigate={~p"/integrations"}>` styled as `.btn btn-primary mt-4` labeled "Connect Integrations". The form is still rendered below the message so the user can still navigate away with Cancel.

Components: `.mf-card`, `.form-control`, `.select.select-bordered`, `.btn.btn-primary`, `.btn.btn-ghost`, `.mf-content`

Responsive: Single-column card stacks naturally on mobile within `max-w-2xl`.
