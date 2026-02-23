MetricFlow [module]
├── Accounts [context] Business accounts and membership management.
├── Agencies [context] Agency-specific features: team management, white-labeling, client account origination.
│   ├── AgenciesRepository [module] Data access layer for agency features — handles CRUD for auto-enrollment rules, white-label configs, team members, an...
│   ├── AutoEnrollmentRule [module] Ecto schema representing domain-based auto-enrollment configuration for agency accounts. Stores email domain patterns...
│   └── WhiteLabelConfig [module] Ecto schema for agency white-label branding configuration. Stores logo URL, primary and secondary brand colors, and c...
├── Ai [context] LLM integration for chat, insights, and report generation.
│   ├── ChatMessage [schema] Individual message: session_id, role, content
│   ├── ChatSession [schema] Chat conversation: user_id, account_id, context
│   ├── Insight [schema] Generated insight: account_id, correlation_id, content, type
│   ├── InsightsGenerator [module] Correlation-based insights
│   ├── LlmClient [module] LLM API integration
│   ├── ReportGenerator [module] Natural language to Vega-Lite
│   └── SuggestionFeedback [schema] User feedback on suggestions
├── Correlations [context] Correlation calculations and analysis results.
│   ├── CorrelationJob [schema] Scheduled/running correlation calculation
│   ├── CorrelationResult [schema] Calculated correlation: account_id, metric_id, goal_metric_id, coefficient, optimal_lag, calculated_at
│   ├── CorrelationWorker [module] Oban worker for correlation calculations
│   └── CorrelationsRepository [module] Correlation queries
├── Dashboards [context] Visualizations and dashboard collections.
│   ├── Dashboard [schema] Collection with name, owner_id, built_in (boolean for canned)
│   ├── DashboardVisualization [schema] Junction: dashboard_id, visualization_id, position, size
│   ├── DashboardsRepository [module] Dashboard CRUD
│   ├── Visualization [schema] Standalone Vega-Lite spec with name, owner_id, vega_spec, shareable
│   └── VisualizationsRepository [module] Visualization CRUD
├── DataSync [context] Sync scheduling, execution, and history tracking. Orchestrates automated daily syncs and manual data pulls from exter...
│   ├── DataProviders
│   │   ├── Behaviour [module] Behaviour contract defining callbacks all data provider implementations must implement. Providers implement fetch_met...
│   │   ├── FacebookAds [module] Facebook Ads provider implementation using Facebook Marketing API v18+. Fetches ad campaign performance metrics inclu...
│   │   ├── GoogleAds [module] Google Ads provider implementation using Google Ads API v16+. Fetches campaign performance metrics including impressi...
│   │   ├── GoogleAnalytics [module] Google Analytics provider implementation using Google Analytics Data API (GA4). Fetches website traffic metrics inclu...
│   │   └── QuickBooks [module] QuickBooks provider implementation using QuickBooks Online Accounting API. Fetches financial metrics including revenu...
│   ├── Scheduler [module] Oban scheduled job that runs daily to enqueue sync jobs for all active integrations. Uses cron schedule to trigger at...
│   ├── SyncHistory [module] Ecto schema representing completed sync records with outcome tracking. Stores user_id, integration_id, provider, stat...
│   ├── SyncHistoryRepository [module] Data access layer for SyncHistory read operations filtered by user_id. All operations are scoped via Scope struct for...
│   ├── SyncJob [module] Ecto schema representing scheduled or running sync jobs. Stores user_id, integration_id, provider, status (pending, r...
│   ├── SyncJobRepository [module] Data access layer for SyncJob CRUD operations filtered by user_id. All operations are scoped via Scope struct for mul...
│   └── SyncWorker [module] Oban worker that executes data sync operations. Receives integration_id and user_id in args. Updates SyncJob status t...
├── Integrations [context] OAuth connections to external platforms. Orchestrates OAuth flows using Assent strategies and provider implementation...
│   ├── Integration [module] Ecto schema representing OAuth integration connections between users and external service providers. Stores encrypted...
│   ├── IntegrationRepository [module] Data access layer for Integration CRUD operations filtered by user_id. All operations are scoped via Scope struct for...
│   └── Providers
│       ├── Behaviour [module] Behaviour contract defining callbacks all OAuth provider implementations must implement. Providers return Assent stra...
│       ├── GitHub [module] GitHub provider implementation using Assent.Strategy.Github. Configures OAuth with user:email and repo scopes. Normal...
│       └── Google [module] Google provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and analytics.edit...
├── Invitations [context] Invitation flow for granting account access.
├── Metrics [context] Unified metric storage and retrieval. Persists metrics from external data providers (Google Analytics, Google Ads, Fa...
│   ├── Metric [module] Ecto schema representing a unified metric data point. Stores metric_type (category like "traffic", "advertising", "fi...
│   └── MetricRepository [module] Data access layer for Metric CRUD and query operations filtered by user_id. All operations are scoped via Scope struc...
├── Users [context] User authentication, registration, and session management.
│   ├── Scope [module]
│   ├── User [module]
│   ├── UserNotifier [module]
│   └── UserToken [module]
└── Vault [module]
MetricFlowWeb [module]
├── AccountLive
│   ├── Index [module] List user's accounts with switcher functionality. Displays all accounts the user belongs to (personal and team), show...
│   ├── Members [module] Manage account members and permissions for the active account. Displays all members with their roles and join dates. ...
│   └── Settings [module] Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name an...
├── AgencyLive
│   └── Settings [liveview] Agency configuration: auto-enrollment, white-label.
├── AiLive
│   ├── Chat [liveview] AI chat interface for data exploration.
│   ├── Insights [liveview] AI insights panel, suggestion feedback.
│   └── ReportGenerator [liveview] Natural language report generation.
├── Application [module]
├── CoreComponents [module]
├── CorrelationLive
│   ├── Goals [liveview] Configure goal metrics.
│   └── Index [liveview] View correlation analysis (Raw and Smart modes), displays automated correlation results.
├── DashboardLive
│   ├── Editor [liveview] Create/edit dashboards, arrange visualizations.
│   ├── Index [liveview] List dashboards (user's and canned).
│   └── Show [liveview] View dashboard with visualizations.
├── ErrorHTML [module]
├── ErrorJSON [module]
├── IntegrationLive
│   ├── Connect [liveview] OAuth connection flow.
│   ├── Index [liveview] List and manage integrations, manual sync trigger.
│   └── SyncHistory [liveview] View sync status and history, shows automated daily sync results.
├── InvitationLive
│   ├── Accept [liveview] Accept invitation flow.
│   └── Send [liveview] Send invitations to users/agencies.
├── Layouts [module]
├── PageController [module]
├── PageHTML [module]
├── PromEx [module]
├── UserAuth [module]
├── UserLive
│   ├── Confirmation [module]
│   ├── Login [liveview] User login and session management.
│   ├── Registration [liveview] User registration and account creation.
│   └── Settings [liveview] User settings including password reset.
├── UserSessionController [module]
└── VisualizationLive
    └── Editor [liveview] Create/edit individual visualizations.