# Architecture Overview

## Root Components

### MetricFlow
**module**

### Accounts
**context**

Business accounts and membership management. Manages the full lifecycle of accounts (personal and team), account membership, role-based authorization, and PubSub notifications for real-time UI updates. All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

### Agencies
**context**

Agency-specific features: team management, white-labeling, client account origination.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Users

### Ai
**context**

Public API boundary for the Ai bounded context.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Correlations
- MetricFlow.Users.Scope

### Binary
**module**

### Correlations
**context**

Public API boundary for the Correlations bounded context.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Integrations
- MetricFlow.Users.Scope

### Dashboards
**context**

Public API boundary for the Dashboards bounded context. Aggregates and shapes metric data from the Metrics context into chart-ready structures for the "All Metrics" dashboard view. Delegates Vega-Lite chart construction to ChartBuilder. Delegates integration presence checks to Integrations.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Integrations
- MetricFlow.Users.Scope

### DataSync
**context**

Sync scheduling, execution, and history tracking. Orchestrates automated daily syncs and manual data pulls from external platforms (Google Ads, Google Analytics, Facebook Ads, QuickBooks), persisting unified metrics through the Metrics context.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Metrics
- MetricFlow.Users

### Integrations
**context**

OAuth connections to external platforms. Orchestrates OAuth flows using Assent strategies and provider implementations, persisting tokens and user metadata through the IntegrationRepository.

Dependencies:
- MetricFlow.Users

### Invitations
**context**

Invitation flow for granting account access.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Users.Scope

### Mailer
**module**

### Metrics
**context**

Unified metric storage and retrieval. Persists metrics from external data providers (Google Analytics, Google Ads, Facebook Ads, QuickBooks) in a normalized format and exposes query functions for dashboards, correlations, AI insights, and goal tracking. All operations are scoped to the current user via Scope struct for multi-tenant isolation.

Dependencies:
- MetricFlow.Users
- MetricFlow.Metrics.MetricRepository

### Release
**module**

### Repo
**module**

### Users
**context**

User authentication, registration, and session management.

### Vault
**module**


## Root Components

### MetricFlowWeb
**module**

### Accept
**module**

### AccountEdit
**module**

### ActiveAccountHook
**module**

### Application
**module**

### Chat
**liveview**

AI chat interface for data exploration. Displays a sidebar of previous chat sessions alongside an active conversation area. Users can start new sessions, continue existing ones, and ask natural language questions about their metrics. Assistant responses are streamed token-by-token.

Dependencies:
- MetricFlow.Ai

### Confirmation
**module**

### Connect
**module**

### CoreComponents
**module**

### Editor
**module**

### Editor
**liveview**

Create/edit individual visualizations.

Dependencies:
- MetricFlow.Dashboards

### Endpoint
**module**

### ErrorHTML
**module**

### ErrorJSON
**module**

### Gettext
**module**

### Goals
**liveview**

Configure goal metrics.

Dependencies:
- MetricFlow.Metrics

### HealthController
**module**

### Index
**liveview**

View correlation analysis (Raw and Smart modes), displays automated correlation results.

Dependencies:
- MetricFlow.Correlations
- MetricFlow.Correlations.CorrelationResult

### Index
**module**

### Index
**module**

### Index
**liveview**

List dashboards (user's and canned).

Dependencies:
- MetricFlow.Dashboards

### Index
**liveview**

List and view saved reports. Displays user-created and system-generated reports including review metric summaries, rolling averages, and cross-platform performance snapshots. Reports aggregate data from the Metrics context into presentable, shareable formats distinct from real-time dashboards.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Dashboards

### Insights
**liveview**

AI insights panel displaying AI-generated recommendations from correlation analysis, with suggestion type filtering and per-insight helpful/not-helpful feedback.

Dependencies:
- MetricFlow.Ai

### IntegrationOAuthController
**module**

### Layouts
**module**

### Login
**module**

### Members
**module**

### OnboardingLive
**module**

### PageController
**module**

### PageHTML
**module**

### PromEx
**module**

### Registration
**module**

### ReportGenerator
**liveview**

Natural language report generation.

Dependencies:
- MetricFlow.Ai

### Router
**module**

### Send
**module**

### Settings
**liveview**

User settings including password reset.

Dependencies:
- MetricFlow.Users

### Settings
**liveview**

Agency configuration: auto-enrollment, white-label. A function component module rendered within the `/accounts/settings` page. Renders two configuration cards — auto-enrollment and white-label branding — conditionally for team account owners and admins.

Dependencies:
- MetricFlow.Agencies
- MetricFlow.Agencies.AutoEnrollmentRule
- MetricFlow.Agencies.WhiteLabelConfig

### Settings
**module**

### Show
**liveview**

View dashboard with visualizations. Displays unified marketing and financial metrics from all connected platforms via Vega-Lite time series charts, summary stat cards, and filter controls. When no integrations are connected, renders an onboarding prompt. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug.

Dependencies:
- MetricFlow.Dashboards

### Show
**liveview**

View a single report with its visualizations and metric summaries. Renders report content including review metrics, rolling averages, and cross-platform comparisons in a read-only presentable format. Supports sharing and export actions.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Dashboards

### SyncHistory
**liveview**

View sync status and history, shows automated daily sync results.

Dependencies:
- MetricFlow.DataSync

### Telemetry
**module**

### UserAuth
**module**

### UserSessionController
**module**

### WhiteLabel
**module**

### WhiteLabelHook
**module**
