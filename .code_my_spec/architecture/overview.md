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

Public API boundary for the Dashboards bounded context. Manages dashboard collections and standalone visualizations. Aggregates and shapes metric data from the Metrics context into chart-ready structures. Delegates Vega-Lite chart construction (single-metric and multi-series) to ChartBuilder. Delegates structured query building to QueryBuilder. Delegates integration presence checks to Integrations.

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
**liveview**

Accept invitation flow. Validates an invitation token from a URL parameter and allows the recipient to accept or decline access to an account. Handles both authenticated users (who accept directly) and unauthenticated users (who are redirected to log in or register before being returned to this page).

Dependencies:
- MetricFlow.Users
- MetricFlow.Invitations

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
**liveview**

OAuth connection flow for linking providers to a user account. Displays OAuth providers (Google, Facebook, QuickBooks) — not individual data platforms — with their current connection status and per-provider OAuth initiation links. Google covers both Google Ads and Google Analytics via a single OAuth connection.

Dependencies:
- MetricFlow.Integrations

### CoreComponents
**module**

### Editor
**liveview**

Create/edit dashboards, arrange visualizations.

Dependencies:
- MetricFlow.Dashboards

### Editor
**liveview**

Create or edit an individual standalone visualization. Authenticated users can select metrics, pick a chart type (line, bar, area), and preview a Vega-Lite chart built from real synced metric data queried from the Metrics context via the Dashboards context. The resulting visualization is saved with its Vega-Lite spec and query parameters, and may later be added to any dashboard via the Dashboard editor. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

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

Configure goal metrics. Allows an authenticated user to select which metric serves as the goal metric against which all other metrics are correlated by the correlation engine.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Correlations

### HealthController
**module**

### Index
**liveview**

View correlation analysis (Raw and Smart modes), displays automated correlation results.

Dependencies:
- MetricFlow.Correlations
- MetricFlow.Correlations.CorrelationResult

### Index
**liveview**

Per-platform data management and sync controls for connected integrations. Shows data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks) rather than OAuth providers. Each platform maps to a parent OAuth provider (e.g., both Google Analytics and Google Ads map to the Google provider). A platform is "connected" when its parent provider has an active integration. OAuth connection management lives on `/integrations/connect`.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.DataSync

### Index
**liveview**

List all accounts the authenticated user belongs to. Displays personal and team accounts with account type, the user's role in each, and any agency access level and origination status for client accounts accessed via an agency grant. Highlights the currently active account and allows switching the active account context. Includes an inline form for creating new team accounts. Requires authentication; unauthenticated requests are redirected to `/users/log-in`. Subscribes to PubSub on mount for real-time account updates.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Agencies

### Index
**liveview**

List dashboards available to the authenticated user. Shows both the user's own saved dashboards and system-provided canned dashboards. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

Dependencies:
- MetricFlow.Dashboards

### Index
**liveview**

List and view saved reports. Displays user-created and system-generated reports including review metric summaries, rolling averages, and cross-platform performance snapshots. Reports aggregate data from the Metrics context into presentable, shareable formats distinct from real-time dashboards.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Dashboards

### Index
**module**

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
**liveview**

User login and session management. Provides two authentication paths: a magic link sent to the user's email address, and direct password-based login. Also handles re-authentication (sudo mode) when a user who is already signed in needs to confirm their identity before performing a sensitive action.

Dependencies:
- MetricFlow.Users

### Members
**liveview**

Manage account members and permissions for the active account. Displays all members with their roles and join dates. Owners and admins can change member roles, remove members, and invite new users. Enforces authorization via `Accounts.Authorization` — only owners/admins see management controls. Protects the last owner from removal or demotion. Subscribes to member PubSub for real-time updates.

Dependencies:
- MetricFlow.Accounts

### OnboardingLive
**module**

### PageController
**module**

### PageHTML
**module**

### PromEx
**module**

### Registration
**liveview**

User registration and account creation.

Dependencies:
- MetricFlow.Users

### ReportGenerator
**liveview**

Natural language report generation. Allows authenticated users to describe a visualization in plain language, generate a Vega-Lite chart spec via the AI context, preview the rendered chart, and optionally save it as a named visualization. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

Dependencies:
- MetricFlow.Ai
- MetricFlow.Dashboards

### Router
**module**

### Send
**liveview**

Send email invitations to users or agencies to grant them access to the active account. Displays a send-invitation form and a list of pending invitations. Only owners and admins of the active account may access this page. Invitations are sent to any email address — the recipient does not need to have an existing account. Pending invitations can be cancelled by the inviting user, an owner, or an admin.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Invitations

### Settings
**liveview**

User account settings page. Allows authenticated users to change their email address and update their password. Requires sudo mode (recent re-authentication) before any changes can be applied.

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
**liveview**

Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name and slug. Only owners can transfer ownership to another admin/member and delete the account. Deletion requires typing the account name for confirmation and re-entering the user's password. Personal accounts cannot be deleted. Subscribes to account PubSub for real-time updates.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Users

### Show
**liveview**

View a dashboard with its visualizations. For the default "All Metrics" canned dashboard, renders a single multi-series Vega-Lite line chart (all metrics as colored lines on one chart) plus an HTML data table (rows = months, columns = metric names, cells = values) with date range picker, platform filter, and metric toggles. For custom user dashboards, renders arranged visualizations from the dashboard's visualization collection. When no integrations are connected, renders an onboarding prompt. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug.

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

