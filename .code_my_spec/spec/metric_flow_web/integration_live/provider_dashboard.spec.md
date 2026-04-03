# MetricFlowWeb.IntegrationLive.ProviderDashboard

Per-provider data dashboard showing synced data in a focused control panel. Each provider gets a dedicated view with key metrics charted over time, recent sync history, sync controls, and connection status. Gives users a concrete place to verify their data is flowing and to monitor provider health.

## Type

liveview

## Route

`/integrations/:provider/dashboard`

## Params

- `provider` - string, provider key (e.g., `google_business`, `google_analytics`, `google_ads`, `facebook_ads`, `quickbooks`)

## Dependencies

- MetricFlow.Integrations
- MetricFlow.Metrics
- MetricFlow.Reviews
- MetricFlow.DataSync

## Components

None

## User Interactions

- **phx-click="sync_now"**: Triggers a manual sync for this provider. Enqueues a SyncWorker Oban job via DataSync, shows a "Sync started" flash, and disables the button until sync completes. On completion (via PubSub), updates the sync history list and last synced timestamp.

- **phx-change="change_date_range"**: Updates the date range filter for metric charts. Re-queries metrics for the selected range and re-renders charts.

- **phx-click="refresh"**: Re-fetches all dashboard data (metrics, reviews, sync history) without triggering a new sync.

## Design

Layout: Full-width page with `max-w-5xl` container, wrapped in `mf-content`.

Page header:
- Provider name as `h1` (e.g., "Google Business Profile Dashboard")
- Connection status badge: `.badge .badge-success` "Connected" or `.badge .badge-error` "Disconnected"
- Connected email or account identifier in `text-base-content/60`
- Last synced timestamp: "Last synced: 2 hours ago" or "Never synced"

Top action bar:
- Date range select: `.select .select-bordered .select-sm` with options (Last 7 days, Last 30 days, Last 90 days, Last 12 months)
- Sync Now button: `.btn .btn-primary .btn-sm` with `data-role="sync-now"`, disabled state while sync is in progress with `.loading` spinner
- Refresh button: `.btn .btn-ghost .btn-sm`

**Metrics section:**

A responsive grid of metric cards: `grid grid-cols-1 md:grid-cols-2 gap-4`.

Each metric card is an `mf-card` with:
- Metric name as card title (e.g., "Sessions", "Review Count", "Revenue")
- Current value as large text
- Vega-Lite line chart showing the metric over the selected date range
- `data-role="metric-card"` on the card, `data-role="metric-chart"` on the chart container

Provider-specific metric cards:
- **google_business**: review_count trend, review_rating trend, call_clicks, direction_requests, website_clicks
- **google_analytics**: sessions, activeUsers, screenPageViews, bounceRate, averageSessionDuration
- **google_ads**: impressions, clicks, cost, conversions, ctr, cpc
- **facebook_ads**: impressions, clicks, spend, conversions, ctr, cpc
- **quickbooks**: revenue, expenses, net_income, gross_profit, cash_on_hand

**Reviews section (google_business only):**

Visible only when `provider == "google_business"`. An `mf-card` with:
- Heading "Recent Reviews" with `data-role="reviews-section"`
- List of up to 10 recent reviews, each showing:
  - Reviewer name in `font-medium`
  - Star rating as filled/empty star icons or numeric badge
  - Review date in `text-base-content/50 text-xs`
  - Comment text truncated to 2 lines with `line-clamp-2`
  - `data-role="review-item"` on each review row

**Sync history section:**

An `mf-card` at the bottom with:
- Heading "Recent Syncs" with `data-role="sync-history-section"`
- Table or list of last 5 sync runs showing:
  - Date/time
  - Status badge: `.badge .badge-success` for success, `.badge .badge-error` for failed, `.badge .badge-warning` for partial
  - Records synced count
  - Duration
  - `data-role="sync-history-row"` on each row

**Empty state:**

When no integration exists for this provider:
- Centered message "Not connected" with a link to `/integrations/connect/:provider`
- `data-role="empty-state"`

**Not found state:**

When the provider param is not a recognized provider:
- Redirect to `/integrations` with error flash

Responsive: On mobile, metric cards stack single-column. Action bar wraps below the header.

## Test Assertions

- renders provider dashboard with provider name and connection status
- shows metric cards with chart containers for the provider
- shows sync history section with recent sync entries
- triggers manual sync and shows sync started flash
- changes date range filter and re-renders metric charts
- shows reviews section for google_business provider
- shows empty state with connect link when provider has no integration
- redirects to integrations for unrecognized provider

