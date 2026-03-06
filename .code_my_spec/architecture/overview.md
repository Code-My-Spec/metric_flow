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

LLM integration for chat, insights, and report generation.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Correlations
- MetricFlow.Dashboards

### Binary
**module**

### Correlations
**context**

Correlation calculations and analysis results.

Dependencies:
- MetricFlow.Metrics

### Dashboards
**context**

Visualizations and dashboard collections.

Dependencies:
- MetricFlow.Metrics

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

### Metrics
**context**

Unified metric storage and retrieval. Persists metrics from external data providers (Google Analytics, Google Ads, Facebook Ads, QuickBooks) in a normalized format and exposes query functions for dashboards, correlations, AI insights, and goal tracking. All operations are scoped to the current user via Scope struct for multi-tenant isolation.

Dependencies:
- MetricFlow.Users
- MetricFlow.Metrics.MetricRepository

### Release
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

Accept invitation flow.

Dependencies:
- MetricFlow.Invitations

### AccountEdit
**module**

### Chat
**liveview**

AI chat interface for data exploration.

Dependencies:
- MetricFlow.Ai

### Confirmation
**module**

### Connect
**liveview**

OAuth connection flow for linking marketing platforms to a user account. Displays all supported platforms (Google Ads, Facebook Ads, Google Analytics) with their current connection status and per-platform OAuth initiation links. Also serves as the OAuth callback handler — when the user returns from the provider, the view processes the authorization code, persists the integration, and shows a confirmation or error message.

Dependencies:
- MetricFlow.Integrations

### Editor
**liveview**

Create/edit dashboards, arrange visualizations.

Dependencies:
- MetricFlow.Dashboards

### Editor
**liveview**

Create/edit individual visualizations.

Dependencies:
- MetricFlow.Dashboards

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

### Index
**liveview**

List and manage integrations, manual sync trigger.

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

List dashboards (user's and canned).

Dependencies:
- MetricFlow.Dashboards

### Insights
**liveview**

AI insights panel, suggestion feedback.

Dependencies:
- MetricFlow.Ai

### IntegrationCallbackController
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

### PromEx
**module**

### Registration
**liveview**

User registration and account creation.

Dependencies:
- MetricFlow.Users

### ReportGenerator
**liveview**

Natural language report generation.

Dependencies:
- MetricFlow.Ai

### Send
**liveview**

Send invitations to users/agencies.

Dependencies:
- MetricFlow.Invitations

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
**liveview**

Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name and slug. Only owners can transfer ownership to another admin/member and delete the account. Deletion requires typing the account name for confirmation and re-entering the user's password. Personal accounts cannot be deleted. Subscribes to account PubSub for real-time updates.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Users

### Show
**liveview**

View dashboard with visualizations.

Dependencies:
- MetricFlow.Dashboards

### SyncHistory
**liveview**

View sync status and history, shows automated daily sync results.

Dependencies:
- MetricFlow.DataSync

### UserAuth
**module**

### UserSessionController
**module**

### WhiteLabel
**module**

### WhiteLabelHook
**module**

