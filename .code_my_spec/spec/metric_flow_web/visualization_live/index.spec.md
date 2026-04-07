# MetricFlowWeb.VisualizationLive.Index

Lists saved visualizations for the authenticated user. Shows all standalone visualizations with name, shareable status, edit/delete actions, and inline delete confirmation. Empty state prompts creation.

## Type

liveview

## Route

`/visualizations`

## Params

None

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-click="delete" phx-value-id={id}** (`data-role="delete-visualization-{id}"`): Sets `confirming_delete` assign to the visualization's integer ID, showing inline delete confirmation on that card.
- **phx-click="confirm_delete" phx-value-id={id}** (`data-role="confirm-delete-{id}"`): Calls `Dashboards.delete_visualization(scope, id)`. On `{:ok, _}`, removes the visualization from the list, clears `confirming_delete`, and flashes "Visualization deleted." On `{:error, :not_found}`, clears `confirming_delete` and flashes "Visualization not found."
- **phx-click="cancel_delete"** (`data-role="cancel-delete"`): Clears `confirming_delete` from assigns without modifying data.

## Design

Layout: Full-width page within `Layouts.app`, content constrained to `max-w-5xl mx-auto`, `.mf-content` wrapper with `px-4 py-8` padding.

Page header (`flex items-start justify-between flex-wrap gap-3 mb-8`):
- Left: H1 "Visualizations" in `text-2xl font-bold`, subtitle "Your saved charts and visualizations" in `text-base-content/60`
- Right: `.btn.btn-primary.btn-sm` "New Visualization" link (`data-role="new-visualization-btn"`) navigating to `/visualizations/new`

Empty state (`data-role="empty-visualizations"`, `.mf-card p-8 text-center`):
- Shown when no visualizations exist
- Muted text "No visualizations yet" and `.btn.btn-primary.btn-sm` "Create your first visualization" link to `/visualizations/new`

Visualization grid (`grid grid-cols-1 sm:grid-cols-2 gap-4`):
- One `.mf-card p-5` per visualization with `data-role="visualization-card"` and `data-visualization-id={id}`
- Visualization name in `font-semibold`
- "Shareable" text in `text-xs text-base-content/60` shown when `shareable` is true
- Action row: `.btn.btn-ghost.btn-sm` "Edit" link (`data-role="edit-visualization-{id}"`) to `/visualizations/{id}/edit`, `.btn.btn-ghost.btn-xs.text-error` "Delete" button
- Inline delete confirmation (`data-role="delete-confirm-{id}"`, shown when `confirming_delete` matches this visualization's id): muted "Are you sure?" text, `.btn.btn-error.btn-xs` "Yes, delete" button, `.btn.btn-ghost.btn-xs` "Cancel" button

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-error`, `.btn-sm`, `.btn-xs`, `.mf-content`

Responsive: Grid collapses to single column on mobile, expands to two columns on sm+. Header row wraps with `flex-wrap gap-3`.
