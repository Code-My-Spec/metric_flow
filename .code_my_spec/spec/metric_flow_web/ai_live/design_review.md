# Design Review

## Overview

Reviewed the MetricFlowWeb.AiLive live context and its 3 child LiveViews (Chat, Insights, ReportGenerator). The architecture is sound — each view has a clear single responsibility, well-defined routes, and appropriate domain context dependencies.

## Architecture

- **Separation of concerns**: Each LiveView handles a distinct AI feature (conversational chat, insight browsing, report generation) with no overlapping responsibilities.
- **No shared LiveComponents**: All three views use inline rendering with no extracted shared components. This is appropriate given the views have distinct UIs with minimal overlap.
- **Dependency boundaries respected**: All views call through public context APIs (`MetricFlow.Ai`, `MetricFlow.Correlations`, `MetricFlow.Dashboards`) — no direct child module access.
- **Route placement**: ReportGenerator sits in the authenticated session (no paywall), while Insights and Chat are behind `RequireSubscriptionHook` — correctly reflecting that AI chat/insights are premium features while report generation is available to all authenticated users.
- **Streaming pattern**: Chat uses async `Task.start` with `handle_info` callbacks for token streaming, which is the standard Phoenix LiveView pattern for long-running operations.

## Integration

- **MetricFlow.Ai**: Primary dependency for all three views — provides `list_insights`, `generate_insights`, `submit_feedback`, `list_chat_sessions`, `create_chat_session`, `send_chat_message`, and `generate_vega_spec`.
- **MetricFlow.Correlations**: Used by Insights to check whether correlation data exists (`get_latest_correlation_summary`, `get_latest_completed_job`).
- **MetricFlow.Dashboards**: Used by ReportGenerator to persist generated visualizations via `save_visualization`.
- **Cross-view navigation**: Insights links to `/correlations` when no correlation data exists; ReportGenerator links to `/visualizations` after saving. No circular navigation dependencies.

## Issues

- **Insights spec missing Correlations dependency**: The Insights LiveView spec listed only `MetricFlow.Ai` as a dependency, but the implementation also uses `MetricFlow.Correlations` for `get_latest_correlation_summary` and `get_latest_completed_job`. Fixed by adding `MetricFlow.Correlations` to the Insights spec Dependencies section.

## Conclusion

The AiLive context is ready for implementation. All specs are consistent, dependencies are validated, and the single issue (missing Correlations dependency in Insights spec) has been fixed.
