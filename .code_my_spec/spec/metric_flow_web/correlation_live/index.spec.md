# MetricFlowWeb.CorrelationLive.Index

View correlation analysis (Raw and Smart modes), displays automated correlation results.

## Type

liveview

## Route

`/correlations`

## Params

None

## Dependencies

- MetricFlow.Correlations
- MetricFlow.Correlations.CorrelationResult

## User Interactions

- **phx-click="set_mode" phx-value-mode="raw"**: Switch the view to Raw mode, showing the sortable results table. Calls no context function — updates `mode` assign only. Active button gets `.btn-primary` styling, inactive gets `.btn-ghost`.
- **phx-click="set_mode" phx-value-mode="smart"**: Switch the view to Smart mode, showing the AI suggestions panel. Calls no context function — updates `mode` assign only. Active button gets `.btn-primary`, inactive gets `.btn-ghost`.
- **phx-click="run_correlations"**: Calls `Correlations.run_correlations/2` with the current goal metric name. On `{:ok, _job}` sets `job_running: true` and flashes an info message. On `{:error, :already_running}` flashes an info message. On `{:error, :insufficient_data}` sets `run_error: :insufficient_data` and flashes an error message. Button is disabled when `job_running` is true.
- **phx-click="sort" phx-value-by="coefficient|metric_name|lag|platform"**: Updates `sort_by` and `sort_dir` assigns. Clicking the active column toggles direction between `:asc` and `:desc`; clicking a different column sets it as the active sort with `:desc` direction. The active column header button gets `data-sort-active="true"`.
- **phx-click="filter_platform" phx-value-platform="all"**: Clears `platform_filter` to nil, showing all results. The "All Platforms" button gets `.btn-primary` styling.
- **phx-click="filter_platform" phx-value-platform="<provider>"**: Sets `platform_filter` to the provider atom, filtering the results table to only rows from that provider. The matching platform button gets `.btn-primary` styling.
- **phx-click="enable_ai_suggestions"**: Sets `ai_suggestions_enabled: true`, replacing the Smart mode opt-in card with the AI recommendations and feedback panel.
- **phx-click="submit_smart_feedback" phx-value-rating="helpful|not_helpful"**: Sets `ai_feedback_submitted: true`, replacing the feedback buttons with a confirmation message. Requires authentication; unauthenticated requests redirect to `/users/log-in` before any event fires.

## Design

Layout: Centered single-column page, `max-w-5xl mx-auto`, `.mf-content` wrapper for z-index above the aurora background. Padding `px-4 py-8`.

On mount, calls `Correlations.get_latest_correlation_summary/1` to load `summary` and `Correlations.list_correlation_jobs/1` to determine `job_running`. Default assigns: `mode: :raw`, `sort_by: :coefficient`, `sort_dir: :desc`, `platform_filter: nil`, `run_error: nil`, `ai_suggestions_enabled: false`, `ai_feedback_submitted: false`. Unauthenticated requests are redirected to `/users/log-in` by the router plug. All context calls are scoped to `current_scope` for multi-tenant isolation.

### Page header

Flex row, space-between, `flex-wrap gap-3`. Left: H1 "Correlations" with muted subtitle "Which metrics drive your goal?". Right: mode toggle group and Run Now button.

- Mode toggle (`data-role="mode-toggle"`): two `.btn btn-sm` side by side — "Raw" (`data-role="mode-raw"`) and "Smart" (`data-role="mode-smart"`). Active mode uses `.btn-primary`; inactive uses `.btn-ghost`.
- Run Now button (`data-role="run-correlations"`): `.btn btn-ghost btn-sm`. Shows `loading-spinner loading-xs` inline when `job_running` is true. `disabled` attribute set when `job_running` is true.

### Job running banner

`data-role="job-running-banner"`. Shown only when `job_running` is true. `.mf-card-cyan p-4` with flex row: `loading-spinner loading-sm` and status message "Correlation analysis is running. This page will reflect the latest results once complete."

### Correlation results wrapper

`data-role="correlation-results"`. Always rendered. Inner content is conditional on state.

**No-data empty state** (`data-role="no-data-state"`) — shown when `summary.no_data` is true and `job_running` is false:
- `.mf-card p-8 text-center` with H2 "No Correlations Yet" and a muted explanatory paragraph covering the 30-day data requirement and Pearson coefficient methodology.
- `<.link navigate={~p"/integrations"}>` styled as `.btn btn-primary mt-6`, label "Connect Integrations".
- When `run_error` is `:insufficient_data`, a `.badge badge-warning` (`data-role="insufficient-data-warning"`) reading "Insufficient data — 30 days of metrics required" appears below the CTA.

**Raw mode** (`data-role="raw-mode"`) — shown when `mode` is `:raw` and `summary.no_data` is false:

Summary bar (`data-role="correlation-summary"`) — flex row of `text-sm text-base-content/60` spans, `flex-wrap`:
- `data-role="goal-metric"`: "Goal: <metric name>" with the name in `font-medium text-base-content`.
- `data-role="last-calculated"`: relative timestamp (e.g., "5 minutes ago", "Jan 31, 2026"). Hidden when `last_calculated_at` is nil.
- `data-role="data-window"`: formatted ISO date range. Hidden when nil.
- `data-role="data-points"`: count with "data points" label. Hidden when nil.

Filter controls (`data-role="filter-controls"`) — flex row of `.btn btn-sm` buttons, `flex-wrap`:
- "All Platforms" — `.btn-primary` when `platform_filter` is nil, else `.btn-ghost`.
- Platform filter (`data-role="platform-filter"`): one button per distinct provider in results, labeled with the human display name (e.g., "Google Ads", "Facebook Ads"). `.btn-primary` when that provider matches `platform_filter`, else `.btn-ghost`.

Results table (`data-role="results-table"`) — `overflow-x-auto` wrapper with `.table table-zebra w-full`:

Sortable header buttons (`phx-click="sort"`) with `data-sort-col` attribute for: Metric, Coefficient, Lag, Platform. Data Points header is not sortable. Active sort column has `data-sort-active="true"` and a `↑` or `↓` arrow.

Each result row (`data-role="correlation-row"` with `data-metric` set to the metric name):
- Metric cell: `font-medium` metric name; muted `text-xs` provider display name below.
- Coefficient cell: `.mf-metric text-sm` in `text-success` (positive), `text-error` (negative), or `text-base-content/60` (zero), followed by a `.badge badge-sm` strength badge (`data-role="strength-badge"`): `badge-success` for "Strong", `badge-warning` for "Moderate", `badge-ghost` for "Weak" or "Negligible".
- Lag cell: muted "Same day" when `optimal_lag` is 0; "<N> days" when non-zero.
- Data Points cell: muted `text-sm` count with "pts" label.
- Platform cell: `.badge badge-ghost badge-sm` with provider display name.

When the filtered result set is empty, a single `colspan="5"` row (`data-role="empty-filter-state"`) shows "No correlations match the selected filter." in muted centered text.

**Smart mode** (`data-role="smart-mode"`) — shown when `mode` is `:smart`:

Before `ai_suggestions_enabled`:
- `.mf-card-accent p-8 text-center` with H2 "Smart Mode", explanatory paragraph about AI surfacing insights, and `.btn btn-primary btn-sm mt-6` button "Enable AI Suggestions" (`data-role="enable-ai-suggestions"`).

After `ai_suggestions_enabled`:
- `data-role="ai-suggestions-enabled"` `.badge badge-success` reading "AI Suggestions enabled".
- `data-role="ai-recommendations"`: H3 "AI Recommendations" and `.mf-card p-6` with recommendation prose and a `<.link navigate={~p"/insights"}>` styled `.link link-primary` to the AI Insights page.
- `data-role="ai-feedback-section"` `.mf-card p-5`:
  - Before submission (`data-role="feedback-helper-text"`): muted helper text and two `.btn btn-ghost btn-sm` buttons — "Helpful" (`data-role="feedback-helpful"`) and "Not helpful" (`data-role="feedback-not-helpful"`).
  - After submission (`data-role="feedback-confirmation"`): success badge checkmark and muted "Thanks for your feedback — helps improve future suggestions." text.
  - Footer: `text-xs text-base-content/40` note "AI suggestions learn from your feedback and improve over time."

Components: `.mf-card`, `.mf-card-cyan`, `.mf-card-accent`, `.table.table-zebra`, `.badge`, `.btn.btn-primary`, `.btn.btn-ghost`, `.loading-spinner`, `.mf-metric`, `.mf-content`

Responsive: Page header wraps with `flex-wrap gap-3`. Summary bar and filter buttons wrap with `flex-wrap`. Results table scrolls horizontally via `overflow-x-auto`.
