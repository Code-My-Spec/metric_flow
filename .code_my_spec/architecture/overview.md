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

List user's accounts with switcher functionality. Displays all accounts the user belongs to (personal and team), shows account type and the user's role in each, and allows switching the active account context via `UserPreferences.select_active_account/2`. The active account is highlighted. Subscribes to PubSub for real-time account and member updates.

Dependencies:
- MetricFlow.Accounts

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

User login and session management.

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

Agency configuration: auto-enrollment, white-label.

Dependencies:
- MetricFlow.Agencies

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

