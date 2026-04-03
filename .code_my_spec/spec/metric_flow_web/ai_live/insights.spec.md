# MetricFlowWeb.AiLive.Insights

AI insights panel displaying AI-generated recommendations from correlation analysis, with suggestion type filtering and per-insight helpful/not-helpful feedback.

## Type

liveview

## Route

`/insights`

## Params

None

## Dependencies

- MetricFlow.Ai

## Components

None

## User Interactions

- **mount**: Reads `current_scope` from socket assigns. Calls `Ai.list_insights(scope, [])` to load all insights for the active account. Calls `Ai.get_feedback_for_insight(scope, insight_id)` for each insight to build a `feedback_map` keyed by insight ID. Assigns `insights`, `feedback_map`, `active_type_filter: :all`, `feedback_submitted: %{}`, `filter_buttons`, and `page_title: "AI Insights"`. Requires authentication; unauthenticated requests redirect to `/users/log-in` via the router authentication plug.
- **phx-click="filter_type"** (type: string): Filters the displayed insights list to show only insights matching the given suggestion type atom. When type is `"all"`, all insights are shown. Updates `active_type_filter` assign. The active filter button is styled with `btn-primary`; inactive buttons use `btn-ghost`.
- **phx-click="submit_feedback"** (insight-id: string, rating: string): Calls `Ai.submit_feedback(scope, insight_id, %{rating: atom})` to persist a helpful or not-helpful rating. All data access is scoped via `current_scope`. On success, updates `feedback_map` and `feedback_submitted` and replaces the feedback buttons with a confirmation message. On `:not_found` error, flashes "Insight not found." On other errors, flashes "Could not save feedback. Please try again."

## Design

Layout: Centered single-column, max-width 4xl, with top padding.

Page header:
  - H1: "AI Insights"
  - Subtitle paragraph: "Actionable recommendations generated from your correlation analysis"

Type filter bar (`data-role="type-filter"`):
  - Row of filter buttons (wrapping on small screens): All, Budget Increase, Budget Decrease, Optimization, Monitoring, General
  - Active filter: `.btn.btn-primary.btn-sm`
  - Inactive filters: `.btn.btn-ghost.btn-sm`

Empty state — no insights (`data-role="no-insights-state"`):
  - Shown when the account has no insights at all
  - `.mf-card` with centered text
  - H2: "No Insights Yet"
  - Subtext explaining insights are generated after a correlation analysis
  - `.btn.btn-primary` link navigating to `/correlations` with label "Run Correlations"

Empty filter state (`data-role="no-filter-results-state"`):
  - Shown when insights exist but the active filter matches none of them
  - `.mf-card` with centered text
  - "No insights match the selected filter." subtext
  - `.btn.btn-ghost.btn-sm` button (`data-role="clear-filter"`) that resets filter to "all" with label "Show All"

Insights list (`data-role="insights-list"`):
  - Vertical stack of insight cards (`.space-y-4`)
  - Each card (`data-role="insight-card"`, `data-insight-id={id}`): `.mf-card.p-5`

Insight card layout (top-to-bottom):
  - Top row (responsive flex): summary text (`data-role="insight-summary"`, `.font-medium`) on the left; badge group on the right
    - Type badge (`data-role="insight-type-badge"`): `.badge.badge-sm` with type-specific color class
      - `budget_increase` → `badge-primary`
      - `budget_decrease` → `badge-warning`
      - `optimization` → `badge-success`
      - `monitoring`, `general` → `badge-ghost`
    - Confidence badge (`data-role="insight-confidence-badge"`, `data-confidence={value}`): `.badge.badge-sm`
      - confidence >= 0.70 → `badge-success`; otherwise `badge-ghost`
      - Formatted as "85% confidence"
  - Full content (`data-role="insight-content"`): `.text-sm.text-base-content/80`
  - Correlation reference (`data-role="insight-correlation-ref"`): shown only when `correlation_result_id` is present; `.text-xs.text-base-content/50`
  - Generated-at timestamp (`data-role="insight-generated-at"`): `.text-xs.text-base-content/40`, formatted as "Jan 01, 2025 at 9:00 AM"
  - Feedback section (`data-role="ai-feedback-section"`): bordered top separator

Feedback section states:
  - No feedback yet (`has_feedback: false`): helper text "Your feedback helps improve future suggestions." (`data-role="feedback-helper-text"`), then two ghost buttons: "Helpful" (`data-role="feedback-helpful"`) and "Not helpful" (`data-role="feedback-not-helpful"`)
  - Feedback already submitted (`has_feedback: true`, determined by `feedback_submitted[insight.id] == true` or `feedback_map[insight.id] != nil`): confirmation row (`data-role="feedback-confirmation"`) with a success badge checkmark and text "Thanks for your feedback — helps improve future suggestions."

AI personalization note (`data-role="ai-personalization-note"`):
  - Shown only when at least one insight exists
  - Centered `.text-xs.text-base-content/40` at the bottom: "AI suggestions learn from your feedback and improve over time."

Components: `.mf-card`, `.btn`, `.badge`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.badge-sm`, `.badge-primary`, `.badge-warning`, `.badge-success`, `.badge-ghost`
Responsive: filter bar wraps on small screens; insight card top row stacks vertically on mobile (`sm:flex-row`)

## Test Assertions

- renders insights page with header and type filter bar
- shows no-insights empty state when account has no insights
- displays insight cards with summary, type badge, confidence badge, and content
- filters insights by type when filter button is clicked
- highlights active filter button with btn-primary
- shows empty filter state when no insights match selected type
- clears filter and shows all insights when Show All is clicked
- submits helpful feedback and shows confirmation message
- submits not helpful feedback and shows confirmation message
- shows feedback confirmation for insights that already have feedback
- shows AI personalization note when insights exist
