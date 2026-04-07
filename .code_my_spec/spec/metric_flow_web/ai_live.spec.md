# MetricFlowWeb.AiLive

AI-powered features UI views.

## Type

live_context

## LiveViews

### AiLive.ReportGenerator

- **Route:** `/reports/generate`
- **Description:** Natural language report generation. Users describe a visualization in plain language, the AI generates a Vega-Lite chart spec, previews the rendered chart, and optionally saves it as a named visualization.

### AiLive.Insights

- **Route:** `/insights`
- **Description:** Displays AI-generated actionable recommendations from correlation analysis with suggestion type filtering and per-insight helpful/not-helpful feedback.

### AiLive.Chat

- **Route:** `/chat`
- **Description:** Conversational AI chat interface for data exploration. Displays a sidebar of previous chat sessions alongside an active conversation area with token-by-token streaming responses.

## Components

None — each LiveView is self-contained with inline rendering.

## Dependencies

- MetricFlow.Ai
- MetricFlow.Correlations
- MetricFlow.Dashboards
