# MetricFlowWeb.IntegrationLive.SyncHistory

View sync status and history, shows automated daily sync results.

## Type

liveview

## Route

`/integrations/sync-history`

## Params

None

## Dependencies

- MetricFlow.DataSync

## Components

None

## User Interactions

- **phx-click="filter" phx-value-status="all"**: Sets `status_filter` to `"all"` in socket assigns. Re-renders the history list showing all entries regardless of status. The All button becomes `.btn-primary`; Success and Failed buttons revert to `.btn-ghost`.
- **phx-click="filter" phx-value-status="success"**: Sets `status_filter` to `"success"`. Re-renders the history list showing only entries with status `success` (both live sync events and persisted records). The Success button becomes `.btn-primary`; others revert to `.btn-ghost`.
- **phx-click="filter" phx-value-status="failed"**: Sets `status_filter` to `"failed"`. Re-renders the history list showing only entries with status `failed`. The Failed button becomes `.btn-primary`; others revert to `.btn-ghost`.
- **handle_info {:sync_completed, payload}**: Received when a sync worker completes successfully. Builds an entry map with `status: "success"` merged from the payload (fields: `provider`, `records_synced`, `completed_at`, `data_date`, optional `sync_type`) and prepends it to the `sync_events` list in assigns. The new entry appears at the top of the history list above all persisted records. Clears the empty state if it was previously shown.
- **handle_info {:sync_failed, payload}**: Received when a sync worker fails. Builds an entry map with `status: "failed"` merged from the payload (fields: `provider`, `reason`, optional `attempt`, `max_attempts`, `data_date`) and prepends it to the `sync_events` list in assigns. Shows retry attempt info ("Attempt {n}/{max}") only when both `attempt` and `max_attempts` are present in the payload.

## Design

Layout: Centered single-column page, `max-w-3xl` container with `px-4 py-8` padding, wrapped in `mf-content`. Unauthenticated users are redirected to `/users/log-in` by the router's `require_authenticated_user` plug before mount. All data is scoped to the authenticated user via `current_scope`.

Page header:
- H1 "Sync History" in `text-2xl font-bold`
- Subtitle "View automated sync results and status" in `text-base-content/60`

Schedule section (`data-role="sync-schedule"`):
- `.mf-card` with `p-5 mb-6`
- H2 "Automated Sync Schedule" in `text-lg font-semibold`
- Description paragraph: "Daily at 2:00 AM UTC — retrieves metrics and financial data per provider, per day. Covers marketing providers (Google Ads, Facebook Ads, Google Analytics) and financial providers (QuickBooks). On first sync, all available historical data is backfilled. Failed syncs are automatically retried up to 3 times with exponential backoff."
- `.badge.badge-info` labeled "Daily"

Date range section (`data-role="date-range"`):
- Muted text showing "Showing data through {yesterday in ISO 8601} (yesterday — today excluded, incomplete day)"
- `date_range_end` is always yesterday (UTC today minus 1 day); today is excluded because the current day is incomplete

Filter tabs row (rendered above history list):
- Three `.btn.btn-sm` buttons: All, Success, Failed
- Active filter button uses `.btn-primary`; inactive buttons use `.btn-ghost`
- Buttons have `data-role` attributes: `filter-all`, `filter-success`, `filter-failed`

Sync history list container (`data-role="sync-history"`):

Empty state (shown only when both `sync_history` and `sync_events` are empty):
- `.mf-card` centered panel with text "No sync history yet."
- Secondary text explaining that Initial Sync entries will appear once the first sync runs, and that the system backfills all available historical data on first sync
- `.badge.badge-ghost` labeled "Initial Sync" with `data-sync-type="initial"`

Sync history entries (one `.mf-card` per entry, `data-role="sync-history-entry"` with `data-status` matching the entry's status). Live events from PubSub broadcasts are rendered first, above all persisted history entries.

Live success entry (`data-status="success"`):
- Provider name in `font-semibold` (`data-role="sync-provider"`)
- `.badge.badge-success` labeled "Success"
- Optional `.badge.badge-ghost` labeled "Initial Sync" when `sync_type: :initial`
- Records synced count: "{n} records synced" in `text-sm text-base-content/60`
- Optional completion timestamp: "Completed at {formatted datetime}" in `text-xs text-base-content/50`
- Optional data date in `text-xs text-base-content/50` aligned right

Live failed entry (`data-status="failed"`):
- Provider name in `font-semibold` (`data-role="sync-provider"`)
- `.badge.badge-error` labeled "Failed"
- Optional error reason in `text-sm text-error` (`data-role="sync-error"`)
- Optional retry counter "Attempt {n}/{max}" in `text-xs text-base-content/50` (shown only when `attempt` and `max_attempts` are present)
- Optional data date aligned right

Persisted success entry (`data-status="success"`):
- Provider name, `.badge.badge-success`, records synced count, completion timestamp, data date derived from `completed_at`

Persisted failed entry (`data-status="failed"`):
- Provider name, `.badge.badge-error`, error message (`data-role="sync-error"`), data date derived from `completed_at`

Persisted partial success entry (`data-status="partial_success"`):
- Provider name, `.badge.badge-warning` labeled "Partial", records synced count, optional error message, completion timestamp, data date

Components: `.mf-card`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.badge`, `.badge-info`, `.badge-success`, `.badge-error`, `.badge-warning`, `.badge-ghost`

Responsive: Single-column layout on all screen sizes. Entry cards stack vertically.
