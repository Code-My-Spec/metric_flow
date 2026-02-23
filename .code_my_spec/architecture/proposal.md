# Architecture Proposal

## Contexts

### MetricFlow.Agencies
Agency-specific features: team management, white-labeling, client account origination.

**Type:** context

**Children:**
- `MetricFlow.Agencies.AutoEnrollmentRule` (schema) - Domain-based auto-enrollment config
- `MetricFlow.Agencies.WhiteLabelConfig` (schema) - Branding: logo, colors, subdomain
- `MetricFlow.Agencies.AgenciesRepository` (module) - Agency feature operations

---

### MetricFlow.DataSync
Sync scheduling, execution, and history tracking.

**Type:** context

**Children:**
- `MetricFlow.DataSync.SyncJob` (schema) - Scheduled/running sync job
- `MetricFlow.DataSync.SyncHistory` (schema) - Completed sync record with status, records_synced, errors
- `MetricFlow.DataSync.Scheduler` (module) - Daily sync scheduling (Oban)
- `MetricFlow.DataSync.SyncWorker` (module) - Oban worker for sync execution
- `MetricFlow.DataSync.DataProviders.GoogleAds` (module) - Pulls Google Ads metrics
- `MetricFlow.DataSync.DataProviders.GoogleAnalytics` (module) - Pulls GA metrics
- `MetricFlow.DataSync.DataProviders.FacebookAds` (module) - Pulls Facebook Ads metrics
- `MetricFlow.DataSync.DataProviders.QuickBooks` (module) - Pulls financial data

---

### MetricFlow.Dashboards
Visualizations and dashboard collections.

**Type:** context

**Children:**
- `MetricFlow.Dashboards.Visualization` (schema) - Standalone Vega-Lite spec with name, owner_id, vega_spec, shareable
- `MetricFlow.Dashboards.Dashboard` (schema) - Collection with name, owner_id, built_in (boolean for canned)
- `MetricFlow.Dashboards.DashboardVisualization` (schema) - Junction: dashboard_id, visualization_id, position, size
- `MetricFlow.Dashboards.VisualizationsRepository` (module) - Visualization CRUD
- `MetricFlow.Dashboards.DashboardsRepository` (module) - Dashboard CRUD

---

### MetricFlow.Correlations
Correlation calculations and analysis results.

**Type:** context

**Children:**
- `MetricFlow.Correlations.CorrelationResult` (schema) - Calculated correlation: account_id, metric_id, goal_metric_id, coefficient, optimal_lag, calculated_at
- `MetricFlow.Correlations.CorrelationJob` (schema) - Scheduled/running correlation calculation
- `MetricFlow.Correlations.CorrelationWorker` (module) - Oban worker for correlation calculations
- `MetricFlow.Correlations.CorrelationsRepository` (module) - Correlation queries

---

### MetricFlow.Ai
LLM integration for chat, insights, and report generation.

**Type:** context

**Children:**
- `MetricFlow.Ai.ChatSession` (schema) - Chat conversation: user_id, account_id, context
- `MetricFlow.Ai.ChatMessage` (schema) - Individual message: session_id, role, content
- `MetricFlow.Ai.Insight` (schema) - Generated insight: account_id, correlation_id, content, type
- `MetricFlow.Ai.SuggestionFeedback` (schema) - User feedback on suggestions
- `MetricFlow.Ai.LlmClient` (module) - LLM API integration
- `MetricFlow.Ai.ReportGenerator` (module) - Natural language to Vega-Lite
- `MetricFlow.Ai.InsightsGenerator` (module) - Correlation-based insights

---

### MetricFlow.Users
User authentication, registration, and session management.

**Type:** context

---

### MetricFlow.Accounts
Business accounts and membership management.

**Type:** context

---

### MetricFlow.Invitations
Invitation flow for granting account access.

**Type:** context

---

### MetricFlow.Integrations
OAuth connections to external platforms.

**Type:** context

---

### MetricFlow.Metrics
Unified metric storage and retrieval.

**Type:** context

---

## Surface Components

### MetricFlowWeb.UserLive.Registration
User registration and account creation.

**Type:** liveview

**Stories:** 424

---

### MetricFlowWeb.UserLive.Login
User login and session management.

**Type:** liveview

**Stories:** 425

---

### MetricFlowWeb.UserLive.Settings
User settings including password reset.

**Type:** liveview

**Stories:** 456

---

### MetricFlowWeb.AccountLive.Index
List user's accounts with switcher functionality.

**Type:** liveview

**Stories:** 431

---

### MetricFlowWeb.AccountLive.Members
Manage account members and permissions.

**Type:** liveview

**Stories:** 426, 430

---

### MetricFlowWeb.AccountLive.Settings
Account settings, ownership transfer, deletion.

**Type:** liveview

**Stories:** 433, 455

---

### MetricFlowWeb.InvitationLive.Send
Send invitations to users/agencies.

**Type:** liveview

**Stories:** 428

---

### MetricFlowWeb.InvitationLive.Accept
Accept invitation flow.

**Type:** liveview

**Stories:** 429, 432

---

### MetricFlowWeb.AgencyLive.Settings
Agency configuration: auto-enrollment, white-label.

**Type:** liveview

**Stories:** 427, 453, 454

---

### MetricFlowWeb.IntegrationLive.Index
List and manage integrations, manual sync trigger.

**Type:** liveview

**Stories:** 436, 438

---

### MetricFlowWeb.IntegrationLive.Connect
OAuth connection flow.

**Type:** liveview

**Stories:** 434, 435, 440

---

### MetricFlowWeb.IntegrationLive.SyncHistory
View sync status and history, shows automated daily sync results.

**Type:** liveview

**Stories:** 437, 439

---

### MetricFlowWeb.DashboardLive.Index
List dashboards (user's and canned).

**Type:** liveview

**Stories:** 444, 445

---

### MetricFlowWeb.DashboardLive.Show
View dashboard with visualizations.

**Type:** liveview

**Stories:** 441

---

### MetricFlowWeb.DashboardLive.Editor
Create/edit dashboards, arrange visualizations.

**Type:** liveview

**Stories:** 443

---

### MetricFlowWeb.VisualizationLive.Editor
Create/edit individual visualizations.

**Type:** liveview

**Stories:** 442

---

### MetricFlowWeb.CorrelationLive.Index
View correlation analysis (Raw and Smart modes), displays automated correlation results.

**Type:** liveview

**Stories:** 447, 448, 449

---

### MetricFlowWeb.CorrelationLive.Goals
Configure goal metrics.

**Type:** liveview

**Stories:** 446

---

### MetricFlowWeb.AiLive.Chat
AI chat interface for data exploration.

**Type:** liveview

**Stories:** 451

---

### MetricFlowWeb.AiLive.Insights
AI insights panel, suggestion feedback.

**Type:** liveview

**Stories:** 450

---

### MetricFlowWeb.AiLive.ReportGenerator
Natural language report generation.

**Type:** liveview

**Stories:** 452

---

## Dependencies

- MetricFlow.Agencies -> MetricFlow.Accounts
- MetricFlow.DataSync -> MetricFlow.Integrations
- MetricFlow.DataSync -> MetricFlow.Metrics
- MetricFlow.Dashboards -> MetricFlow.Metrics
- MetricFlow.Correlations -> MetricFlow.Metrics
- MetricFlow.Ai -> MetricFlow.Metrics
- MetricFlow.Ai -> MetricFlow.Correlations
- MetricFlow.Ai -> MetricFlow.Dashboards
- MetricFlowWeb.UserLive.Registration -> MetricFlow.Users
- MetricFlowWeb.UserLive.Login -> MetricFlow.Users
- MetricFlowWeb.UserLive.Settings -> MetricFlow.Users
- MetricFlowWeb.AccountLive.Index -> MetricFlow.Accounts
- MetricFlowWeb.AccountLive.Members -> MetricFlow.Accounts
- MetricFlowWeb.AccountLive.Settings -> MetricFlow.Accounts
- MetricFlowWeb.InvitationLive.Send -> MetricFlow.Invitations
- MetricFlowWeb.InvitationLive.Accept -> MetricFlow.Invitations
- MetricFlowWeb.AgencyLive.Settings -> MetricFlow.Agencies
- MetricFlowWeb.IntegrationLive.Index -> MetricFlow.Integrations
- MetricFlowWeb.IntegrationLive.Index -> MetricFlow.DataSync
- MetricFlowWeb.IntegrationLive.Connect -> MetricFlow.Integrations
- MetricFlowWeb.IntegrationLive.SyncHistory -> MetricFlow.DataSync
- MetricFlowWeb.DashboardLive.Index -> MetricFlow.Dashboards
- MetricFlowWeb.DashboardLive.Show -> MetricFlow.Dashboards
- MetricFlowWeb.DashboardLive.Editor -> MetricFlow.Dashboards
- MetricFlowWeb.VisualizationLive.Editor -> MetricFlow.Dashboards
- MetricFlowWeb.CorrelationLive.Index -> MetricFlow.Correlations
- MetricFlowWeb.CorrelationLive.Goals -> MetricFlow.Metrics
- MetricFlowWeb.AiLive.Chat -> MetricFlow.Ai
- MetricFlowWeb.AiLive.Insights -> MetricFlow.Ai
- MetricFlowWeb.AiLive.ReportGenerator -> MetricFlow.Ai
