# Architecture Overview

## Root Components

### Accept
**liveview**

Accept invitation flow. Validates an invitation token from a URL parameter and allows the recipient to accept or decline access to an account. Handles both authenticated users (who accept directly) and unauthenticated users (who are redirected to log in or register before being returned to this page).

Dependencies:
- MetricFlow.Invitations


## Root Components

### AccountEdit
**module**

Edit which ad accounts or properties are synced for a connected integration without re-authenticating via OAuth. Loads the existing integration's selected accounts from provider_metadata and presents them as checkboxes. The user toggles selections and saves.

Dependencies:
- MetricFlow.Integrations


## Accounts

### Accounts
**context**

Business accounts and membership management. Manages the full lifecycle of accounts (personal and team), account membership, role-based authorization, and PubSub notifications for real-time UI updates. All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

### Account
**module**

Ecto schema representing a business account. Stores account name, URL-friendly slug, account type (personal or team), and the originator_user_id tracking who created the account. Provides changesets validating name presence, slug format (lowercase letters, numbers, and hyphens), and slug uniqueness. The type field is read-only after creation. Personal accounts are auto-created during user registration; team accounts are created explicitly by users.

### AccountMember
**module**

Ecto schema representing the membership join between a user and an account. Stores account_id, user_id, and role. The role field uses an Ecto.Enum with values :owner, :admin, :account_manager, and :read_only. Provides a changeset validating presence of all required fields and inclusion of role in the valid enum set. The user association is preloaded by AccountRepository when returning member lists.

Dependencies:
- MetricFlow.Accounts.Account

### AccountRepository
**module**

Data access layer for Account and AccountMember CRUD operations. All query functions filter by the calling user's identity extracted from the Scope struct for multi-tenant isolation. Handles transactional operations — account creation atomically inserts the account and owner membership record, and account deletion atomically removes all member records before removing the account. Broadcasts PubSub events after successful mutations.

Dependencies:
- MetricFlow.Accounts.Account
- MetricFlow.Accounts.Authorization
- MetricFlow.Accounts.AccountMember

### Authorization
**module**

Role-based authorization module providing can?/3 predicate functions for all account operations. Accepts a Scope struct, an action atom, and a context map containing the account_id and optionally a target_role. Encodes the role hierarchy: owner > admin > account_manager > read_only. Looks up the calling user's role from the database, then evaluates permissions based on that role and the requested action. Returns false for any user who is not a member of the account.

Dependencies:
- MetricFlow.Accounts.AccountMember


## Root Components

### ActiveAccountHook
**module**

LiveView on_mount hook that loads the active account name for the current scope. Assigns `active_account_name` to the socket so the navigation layout can display which account is currently active. Uses the most recently switched-to account from the user's account list.

Dependencies:
- MetricFlow.Accounts


## Agencies

### Agencies
**context**

Agency-specific features: team management, white-labeling, client account origination.

Dependencies:
- MetricFlow.Accounts

### AgenciesRepository
**module**

Data access layer for agency features — handles CRUD for auto-enrollment rules, white-label configs, team members, and client account access.

Dependencies:
- MetricFlow.Agencies.AutoEnrollmentRule
- MetricFlow.Agencies.WhiteLabelConfig

### AgencyClientAccessGrant
**module**

Ecto schema representing an agency's access grant to a client account. Stores the agency_account_id, client_account_id, access_level, and origination_status. The origination_status distinguishes whether the agency originated the client account (:originator) or was invited (:invited). Enforces a unique constraint on (agency_account_id, client_account_id) to ensure at most one grant per agency-client pair.

Dependencies:
- MetricFlow.Accounts.Account

### AutoEnrollmentRule
**module**

Ecto schema representing domain-based auto-enrollment configuration for agency accounts. Stores email domain patterns, enabled status, and default access level for auto-enrolled users. Enforces one rule per agency via unique constraint. Provides changeset validation for domain format and access level values.

Dependencies:
- MetricFlow.Accounts.Account

### WhiteLabelConfig
**module**

Ecto schema for agency white-label branding configuration. Stores logo URL, primary and secondary brand colors, and custom subdomain. Enforces unique subdomain constraint. Validates hex color format and subdomain format (lowercase letters, numbers, hyphens).

Dependencies:
- MetricFlow.Accounts.Account


## Ai

### Ai
**context**

Public API boundary for the Ai bounded context.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Correlations

### AiRepository
**module**

Data access layer for all Ai context CRUD operations. All queries are scoped by account_id and/or user_id via the Scope struct for multi-tenant isolation. Provides CRUD for Insight, ChatSession, ChatMessage, and SuggestionFeedback records with filtering and ordering.

### ChatMessage
**schema**

Individual message: session_id, role, content

Dependencies:
- MetricFlow.Ai.ChatSession

### ChatSession
**schema**

Chat conversation tied to a user and account, with optional contextual focus on a specific correlation result, metric, or dashboard.

Dependencies:
- MetricFlow.Ai.ChatMessage
- MetricFlow.Accounts.Account

### Insight
**schema**

Ecto schema storing an AI-generated insight derived from correlation analysis. Each record represents
one actionable recommendation produced by InsightsGenerator for a given account, optionally linked
to the specific CorrelationResult that motivated it. Insights carry a suggestion_type enum that
categorises the recommended action, a confidence score between 0.0 and 1.0, and a metadata map for
supplementary context such as metric names and correlation values.

Dependencies:
- MetricFlow.Accounts.Account
- MetricFlow.Correlations.CorrelationResult

### InsightsGenerator
**module**

Correlation-based insights

### LlmClient
**module**

LLM API integration

### ReportGenerator
**module**

Natural language to Vega-Lite

### SuggestionFeedback
**schema**

User feedback on AI-generated suggestions (insights). Each record captures whether a user found a suggestion helpful or not, along with an optional free-text comment. Enforces a unique constraint on `[insight_id, user_id]` so each user submits at most one feedback record per insight. The context layer upserts on this constraint to allow users to change their rating.

Dependencies:
- MetricFlow.Ai.Insight


## Root Components

### Chat
**liveview**

AI chat interface for data exploration. Displays a sidebar of previous chat sessions alongside an active conversation area. Users can start new sessions, continue existing ones, and ask natural language questions about their metrics. Assistant responses are streamed token-by-token.

Dependencies:
- MetricFlow.Ai


## Root Components

### Connect
**liveview**

OAuth connection flow for linking providers to a user account. Displays OAuth providers (Google, Facebook, QuickBooks) — not individual data platforms — with their current connection status and per-provider OAuth initiation links. Google covers both Google Ads and Google Analytics via a single OAuth connection.

Dependencies:
- MetricFlow.Integrations


## Correlations

### Correlations
**context**

Public API boundary for the Correlations bounded context.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Metrics

### CorrelationJob
**schema**

Ecto schema representing a scheduled or completed correlation calculation run. Tracks the
lifecycle of a background Oban job that computes Pearson correlations with time-lagged
cross-correlation (TLCC) between all metrics and a selected goal metric. Scoped to an
Account.

Dependencies:
- MetricFlow.Accounts.Account

### CorrelationResult
**schema**

Ecto schema storing a calculated Pearson correlation between a metric and a goal
metric, including the automatically detected optimal time lag. The coefficient
ranges from -1.0 (perfect anti-correlation) to 1.0 (perfect correlation). The
optimal_lag indicates how many days the metric leads the goal metric (0-30). Only
results backed by at least 30 data points are persisted.

Dependencies:
- MetricFlow.Accounts.Account
- MetricFlow.Correlations.CorrelationJob

### CorrelationWorker
**module**

Oban worker for correlation calculations

### CorrelationsRepository
**module**

Correlation queries

### Math
**module**

Pure functional module implementing statistical calculations. Provides pearson/2 (Pearson correlation coefficient from two float lists), cross_correlate/3 (time-lagged cross-correlation testing lags 0-30, returning optimal lag and coefficient), and extract_values/1 (converts metric time series to aligned float lists). Zero external dependencies — upgrade path to Explorer documented in ADR.


## Dashboards

### Dashboards
**context**

Public API boundary for the Dashboards bounded context. Manages dashboard collections and standalone visualizations. Aggregates and shapes metric data from the Metrics context into chart-ready structures. Delegates Vega-Lite chart construction (single-metric and multi-series) to ChartBuilder. Delegates structured query building to QueryBuilder. Delegates integration presence checks to Integrations.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Metrics

### ChartBuilder
**module**

Pure module for building Vega-Lite chart specifications. Constructs single-metric charts (line, bar, area) and multi-series overlay charts using the vega_lite Elixir package. All functions are pure transformations — they accept data and return a Vega-Lite spec map with no side effects. The generated specs are JSON-encodable and intended to be passed to vega-embed on the client.

### Dashboard
**module**

Named collection of visualizations owned by a user. A dashboard aggregates one or more Visualizations via the DashboardVisualization junction and carries a `built_in` flag that distinguishes system-provided canned dashboards from user-created ones. Canned dashboards are seeded by the application and should not be modified by users.

Dependencies:
- MetricFlow.Dashboards.Visualization
- MetricFlow.Dashboards.DashboardVisualization

### DashboardVisualization
**module**

Junction table linking a Dashboard to a Visualization with layout metadata (position and size). A given visualization may only appear once per dashboard, enforced by a unique database constraint on the `{dashboard_id, visualization_id}` pair.

Dependencies:
- MetricFlow.Dashboards.Visualization
- MetricFlow.Dashboards.Dashboard

### DashboardsRepository
**module**

Dashboard CRUD

### QueryBuilder
**module**

Pure module that builds structured query params from filter inputs (date range, platforms, metric names)

### Visualization
**module**

Standalone Vega-Lite spec with name, owner (user_id), raw vega_spec JSON map, and a shareable flag. A single Visualization may be referenced by many dashboards via the DashboardVisualization join schema, enabling reuse across dashboard collections without duplication. The owning user is referenced via a `belongs_to :user` association enforced by `assoc_constraint/2`. Dashboard membership is expressed through a `has_many :dashboard_visualizations` join.

Dependencies:
- MetricFlow.Dashboards.DashboardVisualization

### VisualizationsRepository
**module**

Visualization CRUD


## DataSync

### DataSync
**context**

Sync scheduling, execution, and history tracking. Orchestrates automated daily syncs and manual data pulls from external platforms (Google Ads, Google Analytics, Facebook Ads, QuickBooks), persisting unified metrics through the Metrics context.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Metrics

### Behaviour
**module**

Behaviour contract defining callbacks all data provider implementations must implement. Providers implement fetch_metrics/2 to retrieve data from external APIs using OAuth tokens, transform provider-specific data formats to unified metric structures, and return ok tuple with metrics list or error tuple with failure reason. Enables separation of concerns between sync orchestration and provider-specific API integration.

Dependencies:
- MetricFlow.Integrations.Integration

### FacebookAds
**module**

Facebook Ads provider implementation using Facebook Marketing API v18+. Fetches ad campaign performance metrics including impressions, clicks, spend, conversions, cpm, cpc, ctr, and conversion_rate with dimension breakdowns by campaign_name, adset_name, and date. Uses Ad Insights endpoint for data retrieval. Transforms API response to unified metric format. Handles ad account selection, cursor-based pagination, and date range filtering. Stores metrics with provider :facebook_ads.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleAds
**module**

Google Ads provider implementation using Google Ads API v16+. Fetches campaign performance metrics including impressions, clicks, cost, conversions, ctr, cpc, and conversion_rate with dimension breakdowns by campaign_name, ad_group_name, and date. Uses GAQL (Google Ads Query Language) for data retrieval. Transforms API response to unified metric format. Handles customer account selection and date range filtering. Stores metrics with provider :google_ads.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleAnalytics
**module**

Google Analytics provider implementation using Google Analytics Data API (GA4). Fetches website traffic metrics including sessions, pageviews, users, bounce_rate, average_session_duration, and new_users with dimension breakdowns by date, source/medium, and page path. Transforms GA4 API response to unified metric format. Handles property selection and date range filtering. Stores metrics with provider :google_analytics.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleBusiness
**module**

Google Business Profile data provider implementing the DataProviders.Behaviour contract. Fetches two categories of data per selected location: performance metrics from the Business Profile Performance API v1 (impressions, conversations, direction requests, call clicks, website clicks, bookings, food orders, food menu clicks) and reviews from the My Business v4 API (individual review records with star ratings, reviewer info, and comments). Iterates all configured locations from integration provider_metadata and returns a flat list of unified metric maps. Accepts an `http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleSearchConsole
**module**

Google Search Console data provider implementing the DataProviders.Behaviour contract. Fetches search performance metrics from the Search Console API (Webmasters v3 searchAnalytics/query endpoint), including clicks, impressions, CTR, and average position. Queries are scoped to a verified site URL and segmented by date dimension only. Paginates results using offset-based row fetching up to a configurable maximum number of pages. Transforms API rows to the unified metric format with provider :google_search_console.

Dependencies:
- MetricFlow.Integrations.Integration

### QuickBooks
**module**

QuickBooks provider implementation using QuickBooks Online Accounting API. Fetches financial metrics including revenue, expenses, net_income, gross_profit, accounts_receivable, accounts_payable, and cash_on_hand from Profit and Loss and Balance Sheet reports. Transforms API response to unified metric format. Handles date range filtering, company (realm) selection, and account hierarchy. Stores metrics with provider :quickbooks.

Dependencies:
- MetricFlow.Integrations.Integration

### Scheduler
**module**

Oban scheduled job that runs daily to enqueue sync jobs for all active integrations. Uses cron schedule to trigger at configured time (e.g., 2am UTC). Queries all integrations across all users, filters to integrations with valid tokens, creates SyncJob records, and enqueues SyncWorker jobs.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.DataSync.SyncJobRepository
- MetricFlow.DataSync.SyncWorker

### SyncHistory
**module**

Ecto schema representing completed sync records with outcome tracking. Stores user_id, integration_id, provider, status (success, partial_success, failed), records_synced count, error messages, started_at, and completed_at timestamps. Belongs to User and Integration. Provides success rate queries and error analysis functions.

Dependencies:
- MetricFlow.Integrations.Integration
- MetricFlow.DataSync.SyncJob

### SyncHistoryRepository
**module**

Data access layer for SyncHistory read operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_history/2 with filter options (provider, limit, offset), get_sync_history/2, and create_sync_history/2 functions. Queries ordered by most recent first.

Dependencies:
- MetricFlow.DataSync.SyncHistory

### SyncJob
**module**

Ecto schema representing scheduled or running sync jobs. Stores user_id, integration_id, provider, status (pending, running, completed, failed, cancelled), started_at, and completed_at timestamps. Belongs to User and Integration. Provides status transition functions and running time calculations.

Dependencies:
- MetricFlow.Integrations.Integration

### SyncJobRepository
**module**

Data access layer for SyncJob CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_sync_jobs/1, get_sync_job/2, create_sync_job/3, update_sync_job_status/3, and cancel_sync_job/2 functions.

Dependencies:
- MetricFlow.DataSync.SyncJob

### SyncWorker
**module**

Oban worker that executes data sync operations. Receives integration_id and user_id in args. Updates SyncJob status to running, retrieves integration tokens, delegates to appropriate DataProvider based on provider, persists metrics via MetricFlow.Metrics, creates SyncHistory record with results, and updates SyncJob status to completed or failed. Handles token refresh when tokens are expired.

Dependencies:
- MetricFlow.DataSync.DataProviders.QuickBooks
- MetricFlow.Integrations
- MetricFlow.DataSync.SyncJobRepository
- MetricFlow.DataSync.DataProviders.GoogleAnalytics
- MetricFlow.Metrics
- MetricFlow.DataSync.DataProviders.FacebookAds
- MetricFlow.DataSync.SyncHistoryRepository
- MetricFlow.DataSync.DataProviders.GoogleAds


## Root Components

### Editor
**liveview**

Create/edit dashboards, arrange visualizations.

Dependencies:
- MetricFlow.Dashboards


## Root Components

### Editor
**liveview**

Create or edit an individual standalone visualization. Authenticated users can select metrics, pick a chart type (line, bar, area), and preview a Vega-Lite chart built from real synced metric data queried from the Metrics context via the Dashboards context. The resulting visualization is saved with its Vega-Lite spec and query parameters, and may later be added to any dashboard via the Dashboard editor. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

Dependencies:
- MetricFlow.Dashboards


## Root Components

### Goals
**liveview**

Configure goal metrics. Allows an authenticated user to select which metric serves as the goal metric against which all other metrics are correlated by the correlation engine.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Correlations


## Root Components

### Index
**liveview**

View correlation analysis (Raw and Smart modes), displays automated correlation results.

Dependencies:
- MetricFlow.Correlations
- MetricFlow.Correlations.CorrelationResult


## Root Components

### Index
**liveview**

Per-platform data management and sync controls for connected integrations. Shows data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks) rather than OAuth providers. Each platform maps to a parent OAuth provider (e.g., both Google Analytics and Google Ads map to the Google provider). A platform is "connected" when its parent provider has an active integration. OAuth connection management lives on `/integrations/connect`.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.DataSync


## Root Components

### Index
**liveview**

List all accounts the authenticated user belongs to. Displays personal and team accounts with account type, the user's role in each, and any agency access level and origination status for client accounts accessed via an agency grant. Highlights the currently active account and allows switching the active account context. Includes an inline form for creating new team accounts. Requires authentication; unauthenticated requests are redirected to `/users/log-in`. Subscribes to PubSub on mount for real-time account updates.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Agencies


## Root Components

### Index
**liveview**

List and view saved reports. Displays user-created and system-generated reports including review metric summaries, rolling averages, and cross-platform performance snapshots. Reports aggregate data from the Metrics context into presentable, shareable formats distinct from real-time dashboards.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Dashboards


## Root Components

### Index
**module**

Lists saved visualizations for the authenticated user. Shows all standalone visualizations with name, shareable status, edit/delete actions, and inline delete confirmation. Empty state prompts creation.

Dependencies:
- MetricFlow.Dashboards


## Root Components

### Index
**liveview**

List dashboards available to the authenticated user. Shows both the user's own saved dashboards and system-provided canned dashboards. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

Dependencies:
- MetricFlow.Dashboards


## Root Components

### Index
**module**

Welcome page and entry point for the onboarding flow. Displays a welcome message and introductory text to guide new users through account setup.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Accounts


## Root Components

### Insights
**liveview**

AI insights panel displaying AI-generated recommendations from correlation analysis, with suggestion type filtering and per-insight helpful/not-helpful feedback.

Dependencies:
- MetricFlow.Ai


## Root Components

### IntegrationOauthController
**controller**

OAuth callback handler for all providers. Receives authorization codes from Google, Facebook, and QuickBooks OAuth flows, exchanges them for tokens via Assent, and persists the integration.

Dependencies:
- MetricFlow.Integrations.OAuthStateStore
- MetricFlow.Integrations


## Integrations

### Integrations
**context**

OAuth connections to external platforms. Orchestrates OAuth flows using Assent strategies and provider implementations, persisting tokens and user metadata through the IntegrationRepository.

### Behaviour
**module**

Behaviour contract defining callbacks all OAuth provider implementations must implement. Providers return Assent strategy configuration via config/0, specify strategy module via strategy/0, and transform provider-specific user data via normalize_user/1. Enables leveraging Assent's battle-tested OAuth implementations while maintaining separation of concerns.

### Codemyspec
**module**

CodeMySpec OAuth provider implementation using Assent.Strategy.OAuth2. Connects to the CodeMySpec platform for issue reporting and feedback. Configures OAuth with read/write scope using CodeMySpec's OAuth2 endpoints. Normalizes user data to the application domain model using the user's email as both name and username.

### Facebook
**module**

Facebook OAuth provider implementation using Assent.Strategy.Facebook. Configures OAuth with `ads_read` scope for accessing Facebook Ads data. Normalizes Facebook user data to the application domain model including provider_user_id, email, name, username, and avatar_url.

### FacebookAdsAccounts
**module**

Fetches accessible Facebook Ad accounts for a Facebook Ads OAuth integration using the Facebook Graph API (`graph.facebook.com`). Queries the `me/adaccounts` endpoint to list ad accounts the authenticated user can access. Returns a flat list of active account maps with `:id`, `:name`, and `:account` keys, filtering out inactive accounts (those without `account_status == 1`). Falls back gracefully with `{:error, :api_disabled}` when the Graph API returns 403 due to insufficient permissions, allowing callers to handle this case explicitly. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### Google
**module**

Google provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and analytics.edit scopes with offline access and consent prompt. Normalizes Google user data to domain model including provider_user_id, email, name, avatar_url, and hosted_domain for Google Workspace accounts.

### GoogleAccounts
**module**

Fetches available GA4 properties for a Google OAuth integration using the Google Analytics Admin API (`analyticsadmin.googleapis.com`). Lists account summaries and their GA4 properties from the API response. Returns a flat list of property maps with `:id`, `:name`, and `:account` keys. Falls back gracefully with `{:error, :api_disabled}` when the Admin API is not enabled in the GCP project (403/SERVICE_DISABLED), allowing callers to offer manual property ID entry. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleAds
**module**

Google Ads OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with the `adwords` scope in addition to email and profile, requesting offline access with a forced consent prompt to ensure a refresh token is issued on every authorisation. Normalizes Google user data to the application domain model by delegating to the shared Google normalization logic.

Dependencies:
- MetricFlow.Integrations.Providers.Google

### GoogleAdsAccounts
**module**

Fetches accessible Google Ads customer accounts for a Google Ads OAuth integration. Uses the Google Ads API `customers:listAccessibleCustomers` endpoint to discover which customer accounts the authenticated user can access, then queries each customer's descriptive name via `googleAds:searchStream`. Returns a flat list of customer maps with `:id`, `:name`, and `:account` keys. Falls back gracefully with `{:error, :api_disabled}` when the Google Ads API returns 403 (insufficient permissions), allowing callers to surface a meaningful error. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleAnalytics
**module**

Google Analytics (GA4) OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with `email`, `profile`, and `analytics.readonly` scopes, requesting offline access with a forced consent prompt to ensure a refresh token is issued on every authorisation. Delegates user data normalization to the shared Google provider module.

Dependencies:
- MetricFlow.Integrations.Providers.Behaviour
- MetricFlow.Integrations.Providers.Google

### GoogleBusiness
**module**

Google Business Profile OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with the `business.manage` scope for accessing Google Business Profile locations and reviews. Delegates user normalization to the Google provider module for shared handling of Google user data.

Dependencies:
- MetricFlow.Integrations.Providers.Google

### GoogleBusinessLocations
**module**

Fetches locations across all Google Business Profile accounts. Uses the My Business Business Information API v1 to list locations for each configured account ID. Handles pagination via `nextPageToken` and merges results into a flat list. When no account IDs are stored in provider_metadata, falls back to fetching accounts from the Account Management API. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### GoogleSearchConsole
**module**

Google Search Console OAuth provider implementation using Assent.Strategy.Google. Configures OAuth with email, profile, and `webmasters.readonly` scopes for accessing Search Console API data with offline access and consent prompt. Delegates user data normalization to the Google provider implementation.

Dependencies:
- MetricFlow.Integrations.Providers.Google

### GoogleSearchConsoleSites
**module**

Fetches verified sites from the Google Search Console API using the Webmasters API v3 sites endpoint. Lists all sites the authenticated user has access to in Search Console. Returns a flat list of site maps with `:id`, `:name`, and `:account` keys where `:id` is the raw `siteUrl`, `:name` is the hostname extracted from the URL (falling back to the raw URL when parsing yields no host), and `:account` is always `"Google Search Console"`. Falls back gracefully with `{:error, :api_disabled}` on a 403 response, which indicates the Search Console API is not enabled or the token lacks sufficient permissions. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### Integration
**module**

Ecto schema representing OAuth integration connections between users and external service providers. Stores encrypted access and refresh tokens with automatic expiration tracking. Enforces one integration per provider per user via unique constraint. Provides expired?/1 and has_refresh_token?/1 helper functions.

### IntegrationRepository
**module**

Data access layer for Integration CRUD operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides upsert_integration/3 for OAuth callback handling, with_expired_tokens/1 for expiration queries, and connected?/2 for existence checks. Cloak handles automatic encryption/decryption of tokens.

Dependencies:
- MetricFlow.Integrations.Integration

### OAuthStateStore
**module**

Server-side ETS-backed store for OAuth session params, keyed by the OAuth `state` token. Runs as a named GenServer that owns the ETS table and periodically purges expired entries. Avoids any reliance on cookies or the Phoenix session, which can be stripped by reverse proxies during 302 redirects.

### QuickBooks
**module**

QuickBooks Online OAuth provider implementation using Assent.Strategy.OAuth2. Configures OAuth with the `com.intuit.quickbooks.accounting` scope using the Intuit OAuth 2.0 endpoints. Normalizes QuickBooks user data to the domain model including provider_user_id, email, name, username, avatar_url, and realm_id for the connected company.

### QuickBooksAccounts
**module**

Fetches income accounts from the QuickBooks Chart of Accounts API for a QuickBooks OAuth integration. Queries the QuickBooks Online REST API for accounts with `AccountType = 'Income'` so users can select which income account to track credits and debits from for correlation analysis. Returns a flat list of account maps with `:id`, `:name`, and `:account` keys. Requires a `realm_id` in the integration's `provider_metadata` to identify the connected QuickBooks company. Falls back gracefully with `{:error, :api_disabled}` when the API returns 403, and with `{:error, :missing_realm_id}` when the integration has no realm_id. Accepts an `:http_plug` option for dependency injection during tests.

Dependencies:
- MetricFlow.Integrations.Integration

### QuickBooksOAuth2
**module**

Custom Assent OAuth2 strategy for QuickBooks Online that skips the userinfo fetch. QuickBooks uses OAuth 2.0 for token exchange but does not reliably support the OpenID Connect userinfo endpoint for the `com.intuit.quickbooks.accounting` scope. The `realmId` (company ID) is returned as a query parameter on the callback URL rather than from a userinfo endpoint. This strategy overrides the base OAuth2 behavior to complete token exchange without a userinfo HTTP call, returning an empty map as the user payload.


## Invitations

### Invitations
**context**

Invitation flow for granting account access.

Dependencies:
- MetricFlow.Accounts

### Invitation
**module**

Ecto schema representing an account access invitation.

Dependencies:
- MetricFlow.Accounts.Account

### InvitationNotifier
**module**

Email delivery module using Swoosh. Sends transactional invitation emails via MetricFlow.Mailer. Delivers account invitation emails to prospective members, including the acceptance URL they must visit to join an account. The raw invitation token is embedded in the acceptance URL and is never stored directly — only its hash is persisted in the database. Invitations expire after 7 days.

### InvitationRepository
**module**

Data access layer for Invitation CRUD operations. All queries filter by account_id for multi-tenant isolation, with the calling user's identity carried by the Scope struct. Provides create_invitation/1 for inserting a new invitation record, get_by_token_hash/1 for secure token lookup with preloaded associations, list_invitations/2 for listing pending invitations scoped to an account, get_invitation/2 for fetching a single invitation by id within an account, and update_invitation/2 for updating invitation status fields.

Dependencies:
- MetricFlow.Invitations.Invitation


## Root Components

### Login
**liveview**

User login and session management. Provides two authentication paths: a magic link sent to the user's email address, and direct password-based login. Also handles re-authentication (sudo mode) when a user who is already signed in needs to confirm their identity before performing a sensitive action.


## Root Components

### Members
**liveview**

Manage account members and permissions for the active account. Displays all members with their roles and join dates. Owners and admins can change member roles, remove members, and invite new users. Enforces authorization via `Accounts.Authorization` — only owners/admins see management controls. Protects the last owner from removal or demotion. Subscribes to member PubSub for real-time updates.

Dependencies:
- MetricFlow.Accounts


## Metrics

### Metrics
**context**

Unified metric storage and retrieval. Persists metrics from external data providers (Google Analytics, Google Ads, Facebook Ads, QuickBooks) in a normalized format and exposes query functions for dashboards, correlations, AI insights, and goal tracking. All operations are scoped to the current user via Scope struct for multi-tenant isolation.

Dependencies:
- MetricFlow.Metrics.MetricRepository

### Metric
**module**

Ecto schema representing a unified metric data point. Stores metric_type (category like "traffic", "advertising", "financial"), metric_name (specific metric like "sessions", "clicks", "revenue"), value as float, recorded_at timestamp, provider atom matching Integration provider enum, and dimensions as embedded map for dimension breakdowns (source, campaign, page, etc.). Belongs to User. Indexed on [user_id, provider], [user_id, metric_name, recorded_at], and [user_id, metric_type].

### MetricRepository
**module**

Data access layer for Metric CRUD and query operations filtered by user_id. All operations are scoped via Scope struct for multi-tenant isolation. Provides list_metrics/2 with filter options (provider, metric_type, metric_name, date_range, limit, offset), get_metric/2, create_metric/2, create_metrics/2 for bulk insert, delete_metrics_by_provider/2, query_time_series/3 for date-grouped aggregation, aggregate_metrics/3 for summary statistics, and list_metric_names/2 for distinct name discovery.

Dependencies:
- MetricFlow.Metrics.Metric

### ReviewMetrics
**module**

Computes rolling review metrics from raw review data stored in the metrics table. Derives three platform-agnostic computed metrics from rows where `metric_type = "reviews"`: daily review count, running total count, and rolling average star rating. All computation is performed in Elixir after fetching daily aggregates from the database, making these metrics provider-agnostic.

Dependencies:
- MetricFlow.Metrics.Metric


## Root Components

### OnboardingLive
**live_context**

Post-registration onboarding flow. Guides new users through initial account setup after signup — currently a welcome stub that will expand into a multi-step wizard for connecting integrations and configuring the workspace.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Accounts

### Index
**module**

Welcome page and entry point for the onboarding flow. Displays a welcome message and introductory text to guide new users through account setup.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.Accounts


## Root Components

### ProviderDashboard
**liveview**

Per-provider data dashboard showing synced data in a focused control panel. Each provider gets a dedicated view with key metrics charted over time, recent sync history, sync controls, and connection status. Gives users a concrete place to verify their data is flowing and to monitor provider health.

Dependencies:
- MetricFlow.Integrations
- MetricFlow.DataSync
- MetricFlow.Metrics
- MetricFlow.Reviews


## Root Components

### Registration
**liveview**

User registration and account creation. Collects email, password, account name, and account type (client or agency). On success, creates the user and account, delivers confirmation email, and shows a success screen.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Agencies


## Root Components

### ReportGenerator
**liveview**

Natural language report generation. Allows authenticated users to describe a visualization in plain language, generate a Vega-Lite chart spec via the AI context, preview the rendered chart, and optionally save it as a named visualization. Unauthenticated requests are redirected to `/users/log-in` by the router's `:require_authenticated_user` pipeline.

Dependencies:
- MetricFlow.Ai
- MetricFlow.Dashboards


## Reviews

### Reviews
**context**

Platform-agnostic review storage, retrieval, and rolling metric aggregation. Reviews are synced from external platforms (Google Business Profile, and future sources like Yelp, Trustpilot) into a dedicated `reviews` table with full review data. The context computes rolling review metrics (daily count, running total, rolling average rating) from this table.

Dependencies:
- MetricFlow.Reviews.ReviewMetrics
- MetricFlow.Reviews.ReviewRepository
- MetricFlow.Reviews.Review

### Review
**schema**

Ecto schema representing an individual customer review. Stores integration_id, provider, external_review_id, reviewer_name, star_rating (1-5), comment text, review_date, location_id, and metadata map for provider-specific fields. Belongs to User via integration. Indexed on [user_id, provider], [user_id, review_date], and [external_review_id] for deduplication during sync.

Dependencies:
- MetricFlow.Integrations.Integration

### ReviewMetrics
**module**

Computes rolling review metrics from the reviews table. Provides query_rolling_review_metrics/2 which returns daily review count, running total count, and rolling average star rating as date-keyed time series. Platform-agnostic — aggregates across all providers. Used by provider dashboards and the correlation engine.

Dependencies:
- MetricFlow.Reviews.Review

### ReviewRepository
**module**

Data access layer for Review CRUD and query operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides create_reviews/2 for bulk upsert (deduplicates on external_review_id), list_reviews/2 with filter options (provider, location_id, date_range, limit, offset), count_reviews/1 for total count, and delete_reviews_by_provider/2.

Dependencies:
- MetricFlow.Reviews.Review


## Root Components

### Send
**liveview**

Send email invitations to users or agencies to grant them access to the active account. Displays a send-invitation form and a list of pending invitations. Only owners and admins of the active account may access this page. Invitations are sent to any email address — the recipient does not need to have an existing account. Pending invitations can be cancelled by the inviting user, an owner, or an admin.

Dependencies:
- MetricFlow.Accounts
- MetricFlow.Invitations


## Root Components

### Settings
**liveview**

Agency configuration: auto-enrollment, white-label. A function component module rendered within the `/accounts/settings` page. Renders two configuration cards — auto-enrollment and white-label branding — conditionally for team account owners and admins.

Dependencies:
- MetricFlow.Agencies
- MetricFlow.Agencies.AutoEnrollmentRule
- MetricFlow.Agencies.WhiteLabelConfig


## Root Components

### Settings
**liveview**

User account settings page. Allows authenticated users to change their email address and update their password. Requires sudo mode (recent re-authentication) before any changes can be applied.


## Root Components

### Settings
**liveview**

Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name and slug. Only owners can transfer ownership to another admin/member and delete the account. Deletion requires typing the account name for confirmation and re-entering the user's password. Personal accounts cannot be deleted. Subscribes to account PubSub for real-time updates.

Dependencies:
- MetricFlow.Accounts


## Root Components

### Show
**liveview**

View a dashboard with its visualizations. For the default "All Metrics" canned dashboard, renders a single multi-series Vega-Lite line chart (all metrics as colored lines on one chart) plus an HTML data table (rows = months, columns = metric names, cells = values) with date range picker, platform filter, and metric toggles. For custom user dashboards, renders arranged visualizations from the dashboard's visualization collection. When no integrations are connected, renders an onboarding prompt. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug.

Dependencies:
- MetricFlow.Dashboards


## Root Components

### Show
**liveview**

View a single report with its visualizations and metric summaries. Renders report content including review metrics, rolling averages, and cross-platform comparisons in a read-only presentable format. Supports sharing and export actions.

Dependencies:
- MetricFlow.Metrics
- MetricFlow.Dashboards


## Root Components

### SyncHistory
**liveview**

View sync status and history, shows automated daily sync results.

Dependencies:
- MetricFlow.DataSync


## Root Components

### WhiteLabel
**module**

Plug that detects agency subdomains and loads white-label configuration. Extracts the first subdomain segment from the request host, looks up the matching WhiteLabelConfig via Agencies context, and stores branding data in the session for the LiveView on_mount hook to assign to the socket.

Dependencies:
- MetricFlow.Agencies


## Root Components

### WhiteLabelHook
**module**

LiveView on_mount hook that loads white-label configuration from the session into socket assigns. The WhiteLabel plug sets the session value based on subdomain; this hook makes it available to LiveView templates for branding customization.

