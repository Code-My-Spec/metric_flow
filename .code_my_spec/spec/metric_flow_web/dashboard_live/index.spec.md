# MetricFlowWeb.DashboardLive.Index

List dashboards available to the authenticated user. Shows both the user's own saved dashboards and system-provided canned dashboards. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

## Type

liveview

## Route

`/dashboards`

## Params

None

## Dependencies

- MetricFlow.Dashboards

## Components

None

## User Interactions

- **phx-click="delete" phx-value-id={id}** (`data-role="delete-dashboard-{id}"`): Opens an inline confirmation prompt for the selected user-owned dashboard. Sets `confirming_delete` in assigns to the dashboard id. Not rendered for canned dashboards.
- **phx-click="confirm_delete" phx-value-id={id}** (`data-role="confirm-delete-{id}"`): Calls `Dashboards.delete_dashboard/2` with the current scope and dashboard id. On `{:ok, _}`, removes the dashboard from the list, clears `confirming_delete`, and flashes "Dashboard deleted." On `{:error, :not_found}`, flashes an error "Dashboard not found." On `{:error, :unauthorized}`, flashes an error "You can't delete that dashboard."
- **phx-click="cancel_delete"** (`data-role="cancel-delete"`): Clears `confirming_delete` from assigns without modifying data.

## Design

Layout: Centered single-column page, `max-w-5xl mx-auto`, `.mf-content` wrapper. Padding `px-4 py-8`.

### Page header

Flex row, space-between, `flex-wrap gap-3`.
- Left: H1 "Dashboards" with muted subtitle "Your saved views and system dashboards".
- Right: `.btn.btn-primary.btn-sm` link "New Dashboard" (`data-role="new-dashboard-btn"`) navigating to `/dashboards/new`.

### Canned dashboards section

`data-role="canned-dashboards"`. Shown when at least one built-in dashboard exists.

- H2 "System Dashboards" with muted subtitle "Pre-built views ready to use".
- Grid `grid grid-cols-1 sm:grid-cols-2 gap-4`.
- Each card (`data-role="dashboard-card"` with `data-dashboard-id={id}` and `data-built-in="true"`, `.mf-card p-5`):
  - Dashboard name in `font-semibold`, optional description in muted `text-sm` below.
  - `.badge.badge-ghost.badge-sm` "Built-in" label.
  - `.btn.btn-ghost.btn-sm` "View" link (`data-role="view-dashboard-{id}"`) navigating to `/dashboards/{id}`.

### User dashboards section

`data-role="user-dashboards"`.

- H2 "My Dashboards" with muted subtitle "Dashboards you've created".
- Empty state (`data-role="empty-user-dashboards"`): Shown when the user has no saved dashboards. `.mf-card p-8 text-center` with muted text "No dashboards yet" and a `.btn.btn-primary.btn-sm` link "Create your first dashboard" navigating to `/dashboards/new`.
- Grid `grid grid-cols-1 sm:grid-cols-2 gap-4` when dashboards exist.
- Each card (`data-role="dashboard-card"` with `data-dashboard-id={id}` and `data-built-in="false"`, `.mf-card p-5`):
  - Dashboard name in `font-semibold`, optional description in muted `text-sm` below.
  - Row with `.btn.btn-ghost.btn-sm` "View" link (`data-role="view-dashboard-{id}"`) navigating to `/dashboards/{id}`, `.btn.btn-ghost.btn-sm` "Edit" link (`data-role="edit-dashboard-{id}"`) navigating to `/dashboards/{id}/edit`, and `.btn.btn-ghost.btn-xs.text-error` "Delete" button (`data-role="delete-dashboard-{id}"`, `phx-click="delete"`, `phx-value-id={id}`).
  - Delete confirmation inline (`data-role="delete-confirm-{id}"`, shown when `confirming_delete` equals this dashboard's id): muted text "Are you sure?" with a `.btn.btn-error.btn-xs` "Yes, delete" button (`data-role="confirm-delete-{id}"`) and a `.btn.btn-ghost.btn-xs` "Cancel" button (`data-role="cancel-delete"`).

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-error`, `.btn-sm`, `.btn-xs`, `.badge`, `.badge-ghost`, `.badge-sm`, `.mf-content`

Responsive: Dashboard grids stack to single column on mobile; expand to two columns on sm+. Page header wraps with `flex-wrap gap-3`.

## Test Assertions

- renders dashboards index page with header and New Dashboard link
- displays canned system dashboards with Built-in badge
- displays user-created dashboards with View, Edit, and Delete actions
- shows empty state when user has no saved dashboards
- shows delete confirmation inline when Delete is clicked
- deletes dashboard and shows success flash on confirm
- cancels delete confirmation without modifying data
- shows error when deleting a non-existent dashboard
