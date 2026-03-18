# Architecture Proposal

## Contexts

### MetricFlow.Users

- **Type:** context
- **Description:** User authentication, registration, and session management.

### MetricFlow.Accounts

- **Type:** context
- **Description:** Business accounts and membership management.

### MetricFlow.Invitations

- **Type:** context
- **Description:** Invitation flow for granting account access.

### MetricFlow.Agencies

- **Type:** context
- **Description:** Agency-specific features: team management, white-labeling, client account origination.

#### Children

- MetricFlow.Agencies.AgenciesRepository (module): Agency feature operations
- MetricFlow.Agencies.AutoEnrollmentRule (schema): Domain-based auto-enrollment config
- MetricFlow.Agencies.WhiteLabelConfig (schema): Branding: logo, colors, subdomain
- MetricFlow.Agencies.AgencyClientAccessGrant (schema): Client-agency access grants

### MetricFlow.Integrations

- **Type:** context
- **Description:** OAuth connections to external platforms.

#### Children

- MetricFlow.Integrations.Integration (schema): OAuth integration record with tokens and metadata
- MetricFlow.Integrations.IntegrationRepository (module): Integration CRUD
- MetricFlow.Integrations.OauthStateStore (module): OAuth state parameter persistence
- MetricFlow.Integrations.GoogleAccounts (module): Google account picker
- MetricFlow.Integrations.FacebookAdsAccounts (module): Facebook Ads account picker
- MetricFlow.Integrations.GoogleAdsAccounts (module): Google Ads account picker
- MetricFlow.Integrations.GoogleSearchConsoleSites (module): Google Search Console site picker
- MetricFlow.Integrations.QuickBooksAccounts (module): QuickBooks company picker

### MetricFlow.DataSync

- **Type:** context
- **Description:** Sync scheduling, execution, and history tracking.

#### Children

- MetricFlow.DataSync.SyncJob (schema): Scheduled/running sync job
- MetricFlow.DataSync.SyncHistory (schema): Completed sync record with status, records_synced, errors
- MetricFlow.DataSync.SyncJobRepository (module): Sync job persistence
- MetricFlow.DataSync.SyncHistoryRepository (module): Sync history persistence
- MetricFlow.DataSync.Scheduler (module): Daily sync scheduling (Oban)
- MetricFlow.DataSync.SyncWorker (module): Oban worker for sync execution
- MetricFlow.DataSync.DataProviders.GoogleAnalytics (module): Pulls GA4 metrics
- MetricFlow.DataSync.DataProviders.GoogleAds (module): Pulls Google Ads metrics
- MetricFlow.DataSync.DataProviders.FacebookAds (module): Pulls Facebook Ads metrics
- MetricFlow.DataSync.DataProviders.GoogleSearchConsole (module): Pulls Search Console metrics
- MetricFlow.DataSync.DataProviders.GoogleBusinessProfile (module): Pulls GBP reviews and performance metrics
- MetricFlow.DataSync.DataProviders.QuickBooks (module): Pulls financial data

### MetricFlow.Metrics

- **Type:** context
- **Description:** Unified metric storage and retrieval. Persists metrics from external data providers in a normalized format and exposes query functions for dashboards, correlations, AI insights, and goal tracking.

#### Children

- MetricFlow.Metrics.Metric (schema): Normalized metric data point with type, name, value, timestamp, provider
- MetricFlow.Metrics.MetricRepository (module): Metric CRUD, time series queries, aggregation, rolling calculations

### MetricFlow.Dashboards

- **Type:** context
- **Description:** Dashboard and visualization management. Aggregates metric data into chart-ready structures, builds Vega-Lite specs, manages dashboard collections with multiple visualizations per dashboard.

#### Children

- MetricFlow.Dashboards.Dashboard (schema): Named dashboard collection with built_in flag for canned dashboards
- MetricFlow.Dashboards.Visualization (schema): Standalone Vega-Lite visualization with name, vega_spec, query_params, shareable flag
- MetricFlow.Dashboards.DashboardVisualization (schema): Join between dashboard and visualization with position/ordering
- MetricFlow.Dashboards.DashboardsRepository (module): Dashboard CRUD and canned dashboard listing
- MetricFlow.Dashboards.VisualizationsRepository (module): Visualization CRUD
- MetricFlow.Dashboards.ChartBuilder (module): Pure Vega-Lite spec builder — single-metric and multi-series overlay charts with color encoding per metric
- MetricFlow.Dashboards.QueryBuilder (module): Pure module that builds structured query params from filter inputs (date range, platforms, metric names)

### MetricFlow.Correlations

- **Type:** context
- **Description:** Correlation calculations and analysis results.

#### Children

- MetricFlow.Correlations.CorrelationResult (schema): Calculated correlation with coefficient, optimal lag
- MetricFlow.Correlations.CorrelationJob (schema): Scheduled/running correlation calculation
- MetricFlow.Correlations.CorrelationWorker (module): Oban worker for correlation calculations
- MetricFlow.Correlations.CorrelationsRepository (module): Correlation queries
- MetricFlow.Correlations.Math (module): Statistical calculations

### MetricFlow.Ai

- **Type:** context
- **Description:** LLM integration for chat, insights, and report generation.

#### Children

- MetricFlow.Ai.ChatSession (schema): Chat conversation with user and account context
- MetricFlow.Ai.ChatMessage (schema): Individual message with role and content
- MetricFlow.Ai.Insight (schema): Generated insight linked to correlation results
- MetricFlow.Ai.SuggestionFeedback (schema): User feedback on AI suggestions
- MetricFlow.Ai.LlmClient (module): LLM API integration via ReqLLM
- MetricFlow.Ai.ReportGenerator (module): Natural language + query results to Vega-Lite spec generation
- MetricFlow.Ai.InsightsGenerator (module): Correlation-based insight generation
- MetricFlow.Ai.AiRepository (module): Chat session and insight persistence

## Surface Components

### MetricFlowWeb.UserLive.Registration

- **Type:** liveview
- **Description:** User registration and account creation.
- **Stories:** 424

### MetricFlowWeb.UserLive.Login

- **Type:** liveview
- **Description:** User login and session management.
- **Stories:** 425

### MetricFlowWeb.UserLive.Settings

- **Type:** liveview
- **Description:** User account settings — email and password changes.
- **Stories:**

### MetricFlowWeb.AccountLive.Index

- **Type:** liveview
- **Description:** List user's accounts with switcher functionality.
- **Stories:** 431

### MetricFlowWeb.AccountLive.Members

- **Type:** liveview
- **Description:** Manage account members and permissions.
- **Stories:** 426, 430

### MetricFlowWeb.AccountLive.Settings

- **Type:** liveview
- **Description:** Account settings, ownership transfer, deletion.
- **Stories:** 433, 455

### MetricFlowWeb.InvitationLive.Send

- **Type:** liveview
- **Description:** Send invitations to users/agencies.
- **Stories:** 428

### MetricFlowWeb.InvitationLive.Accept

- **Type:** liveview
- **Description:** Accept invitation flow.
- **Stories:** 429, 432

### MetricFlowWeb.AgencyLive.Settings

- **Type:** liveview
- **Description:** Agency configuration: auto-enrollment, white-label.
- **Stories:** 427, 453, 454

### MetricFlowWeb.IntegrationLive.Index

- **Type:** liveview
- **Description:** List and manage integrations, manual sync trigger.
- **Stories:** 436, 438

### MetricFlowWeb.IntegrationLive.Connect

- **Type:** liveview
- **Description:** OAuth connection flow for marketing and financial platforms.
- **Stories:** 434, 435, 440

### MetricFlowWeb.IntegrationLive.SyncHistory

- **Type:** liveview
- **Description:** View sync status and history for all providers.
- **Stories:** 437, 439, 509, 510, 511, 513, 516, 517, 518

### MetricFlowWeb.DashboardLive.Index

- **Type:** liveview
- **Description:** List dashboards (user's and canned) and saved reports.
- **Stories:** 444, 445

### MetricFlowWeb.DashboardLive.Show

- **Type:** liveview
- **Description:** View a dashboard with its visualizations. Default canned dashboard renders a multi-series Vega-Lite line chart plus an HTML data table with date range picker, platform filter, and metric toggles.
- **Stories:** 441, 493, 495

### MetricFlowWeb.DashboardLive.Editor

- **Type:** liveview
- **Description:** Create/edit dashboards — name, add/remove/reorder visualizations.
- **Stories:** 443

### MetricFlowWeb.VisualizationLive.Editor

- **Type:** liveview
- **Description:** Create or edit a visualization using real synced metric data and Vega-Lite specs.
- **Stories:** 442

### MetricFlowWeb.ReportLive.Index

- **Type:** liveview
- **Description:** List and view saved reports including review metric summaries and rolling averages.
- **Stories:** 515

### MetricFlowWeb.ReportLive.Show

- **Type:** liveview
- **Description:** View a single report with visualizations and metric summaries.
- **Stories:**

### MetricFlowWeb.CorrelationLive.Index

- **Type:** liveview
- **Description:** View correlation analysis (Raw and Smart modes).
- **Stories:** 447, 448, 449

### MetricFlowWeb.CorrelationLive.Goals

- **Type:** liveview
- **Description:** Configure goal metrics for correlation analysis.
- **Stories:** 446

### MetricFlowWeb.AiLive.Chat

- **Type:** liveview
- **Description:** AI chat interface for data exploration.
- **Stories:** 451

### MetricFlowWeb.AiLive.Insights

- **Type:** liveview
- **Description:** AI insights panel with suggestion feedback.
- **Stories:** 450

### MetricFlowWeb.AiLive.ReportGenerator

- **Type:** liveview
- **Description:** Natural language report generation with real query data.
- **Stories:** 452

## Dependencies

- MetricFlow.Agencies -> MetricFlow.Accounts
- MetricFlow.Agencies -> MetricFlow.Users
- MetricFlow.DataSync -> MetricFlow.Integrations
- MetricFlow.DataSync -> MetricFlow.Metrics
- MetricFlow.DataSync -> MetricFlow.Users
- MetricFlow.Dashboards -> MetricFlow.Metrics
- MetricFlow.Dashboards -> MetricFlow.Integrations
- MetricFlow.Correlations -> MetricFlow.Metrics
- MetricFlow.Correlations -> MetricFlow.Integrations
- MetricFlow.Ai -> MetricFlow.Metrics
- MetricFlow.Ai -> MetricFlow.Correlations
- MetricFlow.Invitations -> MetricFlow.Accounts
- MetricFlowWeb.UserLive.Registration -> MetricFlow.Users
- MetricFlowWeb.UserLive.Login -> MetricFlow.Users
- MetricFlowWeb.UserLive.Settings -> MetricFlow.Users
- MetricFlowWeb.AccountLive.Index -> MetricFlow.Accounts
- MetricFlowWeb.AccountLive.Index -> MetricFlow.Agencies
- MetricFlowWeb.AccountLive.Members -> MetricFlow.Accounts
- MetricFlowWeb.AccountLive.Settings -> MetricFlow.Accounts
- MetricFlowWeb.AccountLive.Settings -> MetricFlow.Users
- MetricFlowWeb.InvitationLive.Send -> MetricFlow.Accounts
- MetricFlowWeb.InvitationLive.Send -> MetricFlow.Invitations
- MetricFlowWeb.InvitationLive.Accept -> MetricFlow.Users
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
- MetricFlowWeb.ReportLive.Index -> MetricFlow.Dashboards
- MetricFlowWeb.ReportLive.Index -> MetricFlow.Metrics
- MetricFlowWeb.ReportLive.Show -> MetricFlow.Dashboards
- MetricFlowWeb.ReportLive.Show -> MetricFlow.Metrics
- MetricFlowWeb.CorrelationLive.Index -> MetricFlow.Correlations
- MetricFlowWeb.CorrelationLive.Goals -> MetricFlow.Metrics
- MetricFlowWeb.AiLive.Chat -> MetricFlow.Ai
- MetricFlowWeb.AiLive.Insights -> MetricFlow.Ai
- MetricFlowWeb.AiLive.ReportGenerator -> MetricFlow.Ai
