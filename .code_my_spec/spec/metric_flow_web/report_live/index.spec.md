# MetricFlowWeb.ReportLive.Index

List and view saved reports. Displays user-created and system-generated reports including review metric summaries, rolling averages, and cross-platform performance snapshots. Reports aggregate data from the Metrics context into presentable, shareable formats distinct from real-time dashboards.

## Type

liveview

## Route

- `/reports` — list all reports for the active account (:index action)
- `/reports/new` — create a new report from template or AI (:new action)

## Params

None

## Dependencies

- MetricFlow.Dashboards
- MetricFlow.Metrics

## Components

None

## User Interactions

- **phx-click=delete phx-value-id={id}**: Opens inline delete confirmation for the report card matching the ID. Sets `confirming_delete` assign.
- **phx-click=confirm_delete phx-value-id={id}**: Calls `Dashboards.delete_visualization/2`. On success, removes the report from the list and flashes Report deleted. On not_found error, flashes Report not found.
- **phx-click=cancel_delete**: Clears `confirming_delete` without modifying data.

## Design

Layout: Centered single-column page, `max-w-5xl mx-auto`, `.mf-content` wrapper.

**Index view (`/reports`):**

Header row: H1 Reports with subtitle. New Report button (`data-role=new-report-btn`) linking to `/reports/new`.

Metric summary strip (`data-role=metric-summary`): flex-wrap row of `.badge.badge-outline` badges showing available metric names. Hidden when no metrics.

Reports list (`data-role=reports-list`):
- Empty state (`data-role=empty-reports`): centered card with Create your first report link.
- Grid of report cards (`data-role=report-card`): name, shareable badge, chart type, View link, Delete button with inline confirmation.
- AI generate CTA card at bottom (`data-role=ai-generate-btn`).

**New view (`/reports/new`):**

Back link, H1 New Report, two option cards: AI generator (`data-role=report-option-ai`) linking to `/reports/generate`, manual builder (`data-role=report-option-manual`) linking to `/visualizations/new`.

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-ghost`, `.btn-sm`, `.btn-xs`, `.badge`, `.badge-outline`, `.badge-ghost`

Responsive: Report cards stack to single column on mobile.

## Test Assertions

- renders reports index page with header and New Report button
- shows available metric badges when metrics exist
- displays saved report cards with name and actions
- shows empty state when no saved reports exist
- shows delete confirmation inline when Delete is clicked
- deletes report and shows success flash on confirm
- cancels delete confirmation without modifying data
- renders new report page with AI and manual creation options
