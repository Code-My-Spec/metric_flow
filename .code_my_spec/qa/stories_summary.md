# Stories

## Story 424 — User Registration and Account Creation

As a new user, I want to register for an account so that I can access the reporting platform and manage my marketing data.

- User can register with email and password
- Email verification is required before account activation
- User is prompted to create an account name during registration
- Account type is specified during registration (Client or Agency)
- User who creates the account becomes the originator and default owner
- After registration, user is logged in and directed to onboarding flow
- Registration form validates email format and password strength
- Duplicate email addresses are rejected with clear error message

## Story 425 — User Login and Session Management

As a registered user, I want to log in securely so that I can access my account and data.

- User can log in with email and password
- Failed login attempts show clear error messages
- User session persists across browser tabs
- User can log out from any page
- Inactive sessions expire after a reasonable period
- User can use Remember me option for extended sessions

## Story 426 — Multi-User Account Access

As an account owner, I want to invite team members (both inside and outside my organization) to my account so that multiple people can access our data with appropriate permissions.

- Account owner or admin can invite users to their account via email
- Each user has their own login credentials
- Users can have different access levels: owner, admin, account manager, read-only
- Access levels follow hierarchy: only owners can add owners, only admins can add admins, etc.
- Account owner can view all users in their account with their access levels
- Account owner or admin can modify user access levels
- Account owner or admin can remove users from the account
- All users on an account see the same data with account-level isolation

## Story 427 — Agency Team Auto-Enrollment

As an agency account owner, I want to automatically add team members from my organization so that I do not have to manually invite each employee.

- Agency can configure domain-based auto-enrollment for their email domain
- Users who register with matching email domain are automatically added to agency account
- Auto-enrolled users get default access level set by agency admin
- Agency admin can view and manage all auto-enrolled team members
- Agency admin can disable auto-enrollment if desired
- Team members automatically inherit access to all client accounts the agency manages

## Story 428 — Client Invites Agency or Individual User Access

As a client account owner, I want to invite agencies or individual users to access my account so that they can help manage my marketing data and reporting.

- Client can send email invitation to any email address (agency or individual)
- Invitation email contains secure link with expiration time of 7 days
- Invitee receives invitation in their email inbox
- Invitation includes client account name and access level being granted
- Client can specify access level in invitation: read-only, account manager, or admin
- Invitation link is single-use and invalidated after acceptance or expiration
- Client can view pending invitations and cancel them before acceptance
- Client can invite multiple agencies or users with different access levels

## Story 429 — Agency or User Accepts Client Invitation

As an invited user, I want to accept a client invitation so that I can access their account and provide services.

- User clicks invitation link and is taken to acceptance page
- If not logged in, user is prompted to log in or register
- Upon acceptance, user account is granted specified access level to client account
- User sees client account added to their account switcher or list
- Expired invitations show clear error message
- Already-accepted invitations cannot be reused
- If invitee is part of an agency, entire agency team gets access based on agency team structure

## Story 430 — Manage User Access Permissions

As a client account owner, I want to manage which users have access to my account so that I can control who can view and modify my data.

- Client can view list of all users with access to their account
- List shows user or agency name, access level, date granted, and whether they are account originator
- Client can modify a user access level to upgrade or downgrade permissions
- Client can revoke a user access at any time
- When access is revoked, user immediately loses ability to view client data
- System logs all permission changes with timestamp and user who made change
- Account originator cannot have their access revoked, only ownership can be transferred

## Story 431 — Agency Views and Manages Client Accounts

As an agency user, I want to easily switch between client accounts I have access to so that I can efficiently manage multiple clients.

- Agency sees list of all client accounts they have access to
- Each client listing shows access level and origination status
- Agency can switch between client accounts via account switcher
- Current client context is clearly displayed in navigation
- Agency with read-only access can only view reports and dashboards
- Agency with account manager access can modify reports and integrations but not delete account or manage users
- Agency with admin access can do everything except delete the account
- Agency cannot see other users who have access to the client account unless they have admin access
- If agency originated the client account, they see Originator badge

## Story 432 — User or Agency Self-Revokes Access

As a user with access to a client account, I want to revoke my own access so that I can cleanly end the relationship.

- User can revoke their own access from client account settings
- Confirmation prompt warns that this action cannot be undone
- After revocation, client account is removed from user account list
- Client is notified via email when user revokes their own access
- User cannot re-access account without new invitation from client
- Account originator cannot self-revoke and must transfer ownership first

## Story 433 — Transfer Account Ownership

As an account owner, I want to transfer ownership of my account to another user so that I can hand off the account when selling a client or changing primary contacts.

- Only current account owner can initiate ownership transfer
- Owner can transfer to existing user with account access or send transfer invitation to new email
- Transfer requires new owner to accept via email confirmation
- Transfer wizard asks: Do you want to make a copy in your own account, Do you want to remain as admin after transfer
- New owner must authenticate or verify identity before accepting
- Upon acceptance, ownership transfers completely to new owner
- Previous owner access level changes based on their selection during transfer
- If account has originator relationship for white-label, originator status can optionally transfer too
- All users are notified of ownership change
- System logs ownership transfer with both parties confirmation

## Story 434 — Connect Marketing Platform via OAuth

As a client user, I want to connect my marketing platforms (Google Ads, Facebook Ads, Google Analytics) so that my marketing data can be automatically synced into the reporting system.

- User can initiate OAuth flow for supported platforms: Google Ads, Facebook Ads, Google Analytics
- OAuth flow opens in popup or new tab with platform authentication
- After successful authentication, user is redirected back to platform selection
- User can select which ad accounts or properties to sync from connected platform
- User can modify selected accounts later without re-authenticating
- Integration is saved only after successful OAuth completion
- User sees confirmation that integration is active and ready to sync
- Failed OAuth attempts show clear error messages
- Platform connection belongs to client account and is not transferable to agency

## Story 435 — Connect Financial Platform via OAuth

As a client user, I want to connect my QuickBooks account so that my revenue data can be correlated with marketing metrics.

- User can initiate OAuth flow for QuickBooks
- OAuth flow authenticates user and grants access to financial data
- After successful authentication, user can select which income accounts to track
- User can select multiple income accounts, system will sum debits and credits
- Integration is saved only after successful OAuth completion
- User sees confirmation that QuickBooks is connected and ready to sync
- Failed OAuth attempts show clear error messages
- Financial data (debits and credits) becomes just another metric in the system for correlation

## Story 436 — View and Manage Platform Integrations

As a client user, I want to view all my connected platforms so that I can manage my integrations and understand what data is being synced.

- User can view list of all connected integrations (marketing and financial)
- Each integration shows platform name, connected date, and sync status
- User can see which ad accounts, properties, or income accounts are selected for each integration
- User can modify selected accounts without re-authenticating
- User can disconnect or remove an integration
- Disconnecting shows warning that historical data will remain but no new data will sync
- User can reconnect a previously disconnected platform
- All integrations treated uniformly with no special QuickBooks UI

## Story 437 — Automated Daily Data Sync

As a system, I want to automatically sync data from all connected platforms daily so that user data stays fresh without manual intervention.

- System runs daily sync job at scheduled time (e.g., 2 AM UTC)
- Sync pulls new data from all active integrations for all accounts
- On first sync after connection, system backfills all available historical data from platform
- Financial data (debits and credits) is stored as metrics alongside marketing metrics
- Sync retrieves metrics, review data, and financial data for each day
- OAuth tokens are automatically refreshed when needed
- Failed syncs are automatically retried up to 3 times with exponential backoff
- Sync errors are logged with details for debugging
- Default date ranges exclude today to avoid showing zero for incomplete day

## Story 438 — Manual Sync Trigger (Admin)

As an admin user, I want to manually trigger a data sync so that I can debug integration issues or get fresh data on demand.

- Admin users see Sync Now button in integration settings
- Clicking sync triggers immediate data pull for that integration
- UI shows sync in progress with loading indicator
- Upon completion, user sees success message with timestamp and records synced
- If sync fails, error details are displayed
- Manual sync does not interfere with automated daily sync schedule

## Story 439 — Sync Status and History

As an admin user, I want to view sync history and status for each integration so that I can diagnose issues and understand data freshness.

- Each integration shows last successful sync timestamp
- Each integration shows next scheduled sync time
- User can view detailed sync history (last 30 syncs minimum)
- Sync history shows: timestamp, status (success or failure), records synced, and any error messages
- Failed syncs are highlighted with error details
- User can filter sync history by status (all, success, failed)

## Story 440 — Handle Expired or Invalid OAuth Credentials

As a client user, I want to be notified when my platform credentials expire so that I can reconnect and resume data syncing.

- When OAuth token refresh fails, integration status changes to Needs Reconnection
- User sees warning indicator on integration in dashboard
- User receives email notification about expired credentials
- User can click Reconnect button to re-initiate OAuth flow
- After successful reconnection, sync resumes automatically
- System does not delete historical data when credentials expire

## Story 441 — View All Metrics Dashboard

As a client user, I want to see all my metrics from all platforms in one unified view so that I can understand my complete marketing and financial picture.

- User can access All Metrics dashboard showing data from all connected platforms
- Dashboard displays both marketing metrics and financial metrics with no distinction
- User can filter by platform, date range, or metric type
- User can select date range: last 7 days, 30 days, 90 days, all time, custom
- Date ranges default to last X days from yesterday to avoid incomplete current day
- Dashboard updates dynamically when filters change
- If no integrations connected, dashboard shows onboarding prompts
- All visualizations use Vega-Lite

## Story 442 — Flexible Chart Visualization Options

As a client user, I want to view my data using different chart types so that I can visualize information in the way that makes most sense to me.

- User can select from multiple chart types: line, bar, donut, Gantt, scatter, area, etc.
- User can switch chart types for any metric without losing filters or selections
- All charts render using Vega-Lite specifications
- Charts are interactive (hover for details, click to drill down where applicable)
- User can add multiple charts to same view for comparison
- Chart settings are saved with report when user saves

## Story 443 — Create and Save Custom Reports

As a client user, I want to create and save custom reports so that I can track specific metrics important to my business.

- User can create new report from template or blank canvas
- User can add visualizations by selecting metrics and chart types
- User can arrange visualizations in layout (drag and drop or grid)
- User can name and save report
- Saved reports appear in user report list
- User can edit saved reports
- User can delete saved reports
- Reports can include metrics from any connected platform (marketing and financial)
- Reports use vega lite
- Report editor includes the canned vega lite editor

## Story 444 — Default Canned Dashboards

As a client user, I want to access pre-built dashboard templates so that I can quickly get insights without building custom reports.

- System provides default dashboard templates (e.g., Marketing Overview, Revenue Analysis, Platform Comparison)
- User can select template and it auto-populates with their data
- User can customize canned dashboards and save as their own
- Canned dashboards update automatically as new data syncs
- User can reset to default template if they have customized
- Canned dashboards use vega lite visualizations
- Canned dashboards include line charts shoting base metrics

## Story 445 — View and Navigate Saved Reports

As a client user, I want to access my saved reports easily so that I can review important metrics regularly.

- User can view list of all saved reports
- Reports are sorted by last modified date
- User can search reports by name
- Clicking report opens it in full view
- Report maintains selected date range from last viewing
- User can set report as favorite for quick access
- User can duplicate reports to create variations

## Story 446 — Select Goal Metrics for Correlation

As a client user, I want to specify which metrics are my business goals so that the system can identify what drives those outcomes.

- User can access Goal Metrics configuration from menu
- User can select one or more metrics as goals (e.g., revenue account from QuickBooks)
- Selected goal metrics are highlighted or badged in metric lists
- User can modify goal metrics at any time
- System stores goal metrics per account
- When user selects goal metrics, system queues correlation analysis

## Story 447 — Automated Correlation Analysis

As a client user, I want to see which marketing metrics correlate most with my goal metrics so that I can focus on activities that drive business results.

- System automatically calculates correlations between all metrics and selected goal metric(s)
- Correlations are calculated daily after data sync completes
- System tests multiple time lags (0-30 days) for each metric to automatically find optimal lag
- System selects lag with highest absolute correlation value for each metric
- Correlation calculations use daily aggregated data
- Only correlations meeting minimum data threshold are calculated (e.g., 30+ days of data)
- Correlation runs against ALL metrics (financial and marketing treated the same)

## Story 448 — View Correlation Analysis Results (Raw Mode)

As a client user, I want to view raw correlation analysis results so that I can analyze data myself without AI suggestions.

- User can access correlation analysis from main navigation
- User can toggle between Raw and Smart/AI modes
- In Raw mode: analysis shows ranked list of ALL correlations (strongest to weakest)
- Each correlation shows: metric name, correlation coefficient, optimal lag in days, time period analyzed
- User can sort by: correlation strength, metric name, platform, lag time
- User can view both positive and negative correlations
- User can filter by platform or metric type
- User can select different time windows for analysis (30 days, 90 days, all time)
- Results update when user changes time window or filters
- If insufficient data exists, user sees message explaining minimum requirements

## Story 449 — View Correlation Analysis Results (Smart/AI Mode)

As a client user, I want to see AI-curated correlation insights so that I can quickly understand what matters most without analyzing raw data.

- In Smart/AI mode: analysis shows top 5 positive and top 5 negative correlations
- Only correlations above minimum threshold are shown (e.g., absolute value greater than 0.3)
- Results are presented with explanations (e.g., Google Ads spend shows strong correlation with revenue at 7-day lag)
- AI can highlight which correlations are most meaningful based on context
- User can still access full ranked list if desired
- Mode selection (Raw vs Smart) is saved per user preference

## Story 450 — AI Insights and Suggestions

As a client user, I want to get AI-powered suggestions based on my correlation data so that I can make informed decisions about where to invest.

- User can enable AI Suggestions option in Smart mode
- AI analyzes correlation data and provides actionable recommendations (e.g., Increase Google Ads budget based on 0.85 correlation with revenue)
- Each chart or visualization can have an AI info button
- Clicking AI button shows context-specific insights or opens chat about that metric
- AI suggestions are based on correlation strength, trends, and business context
- User can provide feedback on suggestions (helpful or not helpful)
- AI learns from feedback to improve future suggestions

## Story 451 — AI Chat for Data Exploration

As a client user, I want to chat with AI about my data so that I can ask questions and get insights in natural language.

- User can open AI chat from any report or visualization
- Chat context includes relevant data from current view
- User can ask questions like Why did my revenue drop last week
- AI has access to all metrics and correlation data to answer
- AI can suggest visualizations or reports based on questions
- Chat history is saved per user
- User can share chat insights with team members

## Story 452 — LLM-Generated Custom Reports

As a client user, I want to describe a report in natural language and have it generated automatically so that I can create custom visualizations without learning Vega-Lite syntax.

- User can enter natural language description of desired report
- LLM generates valid Vega-Lite specification
- User can preview generated visualization
- User can provide feedback to refine the visualization
- Generated report can be saved like any other custom report
- User can edit Vega-Lite spec directly if desired (advanced mode)
- System logs all LLM interactions for debugging

## Story 453 — Agency White-label Configuration

As an agency account owner, I want to configure white-label branding for my agency so that clients see my brand when accessing reports.

- Agency can upload custom logo (supports PNG, JPG, SVG)
- Agency can set custom color scheme (primary, secondary, accent colors)
- Agency can configure custom subdomain (e.g., reports.andersonthefish.com)
- Changes preview in real-time before saving
- Agency can reset to default branding
- White-label settings are stored at agency account level
- Custom subdomain requires DNS verification before activation
- No Anderson Analytics branding visible on white-labeled instances

## Story 454 — Client Views White-labeled Interface

As a client user, I want to see my agency branding when they have originated my account so that the experience feels professional and cohesive.

- When client accesses system via agency custom subdomain, they see agency branding
- Agency logo appears in navigation header
- Agency color scheme is applied throughout interface
- When client accesses via main domain, they see default branding
- If agency is account originator, white-labeling is always applied for that client
- Client can still customize their own dashboards regardless of white-labeling
- White-label branding does not affect functionality, only visual appearance

## Story 455 — Account Deletion (Owner Only)

As an account owner, I want to delete my account permanently so that I can remove all my data from the system.

- Only account owner role can access delete account option
- Account originator cannot delete account they originated (only owner can)
- Delete requires confirmation with account name typed in
- Delete requires password re-entry for security
- Warning explains that deletion is permanent and irreversible
- Upon deletion, all account data is removed (metrics, reports, integrations)
- All user access grants to this account are revoked
- User receives confirmation email after deletion
- Admin and other roles cannot delete account

## Story 493 — Cross-Platform Metric Normalization and Mapping

As a client user, I want the system to recognize that equivalent metrics from different platforms represent the same concept (e.g., a Google Ads click is the same as a Facebook Ads click), so that I can accurately compare and aggregate the same metric across platforms without manual reconciliation.

- System maintains a canonical metric taxonomy (e.g., 'clicks', 'spend', 'impressions', 'conversions') that platform-specific metrics map to
- Each platform integration defines mappings from its native metric names to canonical metrics (e.g., Google Ads 'Clicks' and Facebook Ads 'Link Clicks' both map to canonical 'clicks')
- When a platform metric does not have a direct equivalent in the canonical taxonomy, it is stored as a platform-specific metric and clearly labeled as such
- Users can view which platform metrics are mapped to which canonical metrics
- Mapped metrics can be aggregated across platforms in dashboards and reports using canonical names
- Mapped metrics can be compared side-by-side across platforms (e.g., Google Ads clicks vs Facebook Ads clicks on the same chart)
- Metric mappings account for known semantic differences (e.g., different attribution windows or counting methods) and surface these as warnings or footnotes when comparing
- New platform integrations can define their metric mappings without requiring changes to existing canonical definitions
- Derived metrics (e.g., CPC) that reference canonical component metrics automatically work across platforms once their components are mapped

## Story 495 — Correct Aggregation of Derived and Calculated Metrics

As a client user, I want calculated metrics like cost-per-click or conversion rate to be aggregated correctly when viewed across time periods or platforms, so that I see mathematically accurate numbers rather than misleading averages of averages.

- System distinguishes between raw/additive metrics (e.g., clicks, spend, impressions) and derived/calculated metrics (e.g., CPC, CTR, conversion rate, ROAS)
- Derived metrics are defined by a formula referencing their component raw metrics (e.g., CPC = total spend / total clicks)
- When aggregating derived metrics across time periods (e.g., daily to weekly), system sums the component metrics first then calculates the derived value from the aggregated components
- When aggregating derived metrics across multiple platforms or ad accounts, system sums the component metrics first then calculates the derived value from the aggregated components
- System never averages a derived metric directly across rows - it always re-derives from aggregated components
- Derived metric definitions are stored as metadata and can be extended for new metric types
- If a component metric has missing data for a time period, the derived metric for that period reflects the gap rather than silently producing incorrect values
- Derived metrics display identically to raw metrics in dashboards and reports - the aggregation logic is transparent to the user

## Story 509 — Sync Google Analytics 4 Data

As a client user, I want my Google Analytics 4 property data to be synced daily so that website traffic and engagement metrics are available alongside my marketing spend and revenue data for correlation analysis.

- System fetches GA4 data using the Google Analytics Data API v1 (runReport endpoint), not the Universal Analytics API
- Data is fetched per GA4 property selected during OAuth connection
- System syncs the following GA4 metrics as core daily values: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers
- Each metric is stored as a daily time-series value keyed to the property and client account
- On first sync, system backfills up to 548 days of historical GA4 data (approximately 18 months); on subsequent syncs, fetches from the day after the last stored metric date
- Subsequent daily syncs fetch data for yesterday only (avoids incomplete current-day data)
- Sampled data responses are detected and flagged — system logs a warning and stores data with a sampling caveat
- System handles GA4 API quota limits with exponential backoff and retry (default quota: 10 requests/second/project)
- If GA4 API returns no data for a day (e.g., property had no traffic), a zero-value record is stored rather than a gap
- GA4 metrics are mapped to canonical metric names in the cross-platform metric taxonomy (e.g., GA4 'sessions' maps to canonical 'sessions')
- GA4-specific metrics that have no canonical equivalent are stored as platform-specific metrics labeled 'Google Analytics: [metric name]'
- Sync failures for a GA4 property are logged with the API error response and surfaced in Sync Status and History
- Data fetched is scoped to the date range dimension only — no other dimensions (e.g., source/medium) are stored at this stage
- Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is identical to a single-request response would be
- Because GA4's runReport endpoint has a 10-metric limit per request, metrics are fetched in chunks of 10 and results are merged by date before storage; the final stored data is equivalent to what a single-request response would contain

## Story 510 — Sync Google Ads Data

As a client user, I want my Google Ads account data to be synced daily so that advertising spend and performance metrics are available alongside my other platform data for correlation analysis.

- System fetches Google Ads data using the Google Ads API via the google-ads-api client library, querying the 'customer' entity with date segments
- Data is fetched per Google Ads customer ID (googleAdsPropertyId) configured for each account
- System requires a valid GOOGLE_DEVELOPER_TOKEN environment variable and a manager account ID (GOOGLE_MANAGER_ACCOUNT_ID) to authenticate API calls
- OAuth refresh token from the stored Google token set is used per request — no separate Google Ads OAuth flow
- System syncs the following metrics as core daily values: clicks, impressions, cost_micros (converted to cost by dividing by 1,000,000), all_conversions, conversions
- Metrics are fetched at account level only (customer entity, no campaign or ad group segmentation) — one row per day per metric
- Data fetched is segmented by date only — no additional dimensions (e.g., campaign, device, network) are stored at this stage; adding dimensions would require schema changes and re-aggregation logic before correlation can be run
- On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date
- Sync uses retryWithBackoff with up to 3 retries and 2-second initial delay for transient API errors
- Google Ads API errors are extracted from error.response.errors[0] and surfaced with full context (customerId, dateRange, errorCode)
- Sync failures are logged with full error details and surfaced in Sync Status and History
- cost_micros is always divided by 1,000,000 before storage so all cost values are in standard currency units

## Story 511 — Sync Facebook Ads Data

As a client user, I want my Facebook Ads account data to be synced daily so that advertising spend, reach, and conversion metrics are available alongside my other platform data for correlation analysis.

- System fetches data using facebook-nodejs-business-sdk, calling account.getInsights() at account level with time_increment: 1 (daily breakdown)
- Data is fetched per facebookAdsAccountId from config; the 'act_' prefix is added by the fetcher at call time, not stored in config
- Authentication uses a dedicated Facebook OAuth flow separate from Google OAuth, requiring FACEBOOK_APP_ID, FACEBOOK_APP_SECRET, and ads_read scope
- Metrics are fetched at account level only — one row per day; no campaign, adset, or ad segmentation at this stage
- Core scalar metrics synced daily: impressions, reach, clicks, spend, cpp, unique_clicks, unique_ctr, frequency, cost_per_ad_click, cost_per_conversion
- The 'actions' API field is expanded from array into flat keys as 'actions:{action_type}' for: link_click, page_engagement, post_engagement, post_reaction, comment, like, share, video_view, lead, purchase, complete_registration, add_to_cart, checkout
- The 'cost_per_action_type' field is expanded into flat keys as 'cost_per_action_type:{action_type}' for the same action type list
- Video completion metrics (video_p25/50/75/100_watched_actions) are arrays — only the video_view action_type entry is extracted and stored as a scalar per metric
- Rows missing date_start are skipped with a warning; non-numeric metric values are skipped silently
- On first sync, system backfills 180 days of history; subsequent syncs fetch from the day after the last stored metric date
- Sync uses retryWithBackoff with 3 retries and 2-second initial delay; Facebook API errors are extracted from error.response.error
- Polly HTTP record/replay is initialized per fetch and stopped in the finally block — testing tool only, must not affect production sync
- Sync failures are logged with full error details and surfaced in Sync Status and History

## Story 513 — Sync Google Business Profile Reviews

As a client user, I want my Google Business Profile reviews synced so that review volume and ratings are available as daily metrics alongside my marketing and financial data for correlation analysis.

- System fetches reviews using the Google My Business API v4 (mybusiness.googleapis.com/v4) via direct HTTP with a Google OAuth access token — not the Analytics or Ads client libraries
- Reviews are fetched per location ID under the customer's googleBusinessAccountId; the 'locations/' prefix is stripped from location IDs before API calls
- All reviews are fetched via paginated requests (pageSize: 100, orderBy: updateTime desc) until no nextPageToken is returned — full history is always retrieved, not a windowed date range
- Each review is stored in the Review table with: externalAccountId, externalLocationId, externalReviewId, reviewerName, rating (Google enum ONE-FIVE converted to integer 1-5), comment, reply, replyDate, reviewDate, status (PUBLISHED), and metadata (reviewType, languageCode)
- KNOWN LIMITATION: Before each sync run, all existing Review records and all Metric records with keys prefixed 'BUSINESS_REVIEW_' are fully deleted before re-inserting — sync is a full rebuild; if sync fails midway, all historical data is lost until next successful run. Preferred future behavior: upsert on externalReviewId instead.
- After reviews are stored, the aggregator walks day-by-day from earliest to latest review date calculating for each day: dailyReviewCount (reviews on that exact day), totalReviews (rolling count of all reviews up to that day), and averageRating (rolling average of all ratings up to that day
- Only BUSINESS_REVIEW_DAILY_COUNT is stored as a Metric record per day per location — averageRating and totalReviews are calculated during aggregation but not currently persisted as separate metric rows
- Metrics are stored at location level (externalLocationId is populated), unlike the ad platform integrations which store at account level with null locationId
- Location details (title, storeCode) are fetched during metric formatting to generate the metric label — if location details are unavailable the sync for that location fails with an error
- Sync processes all locations listed in customerConfig.includedLocations for each customer; customers without googleBusinessAccountId are skipped
- Sync failures for individual customers are caught and logged but do not halt processing of other customers; a summary of successes and failures is returned at the end

## Story 515 — Calculate Rolling Review Metrics from Review Table

As a system, I want to derive daily rolling review metrics from the Review table regardless of source platform, so that review performance can be correlated with marketing and financial data across any platform that produces reviews.

- Metric calculation is platform-agnostic — it operates on the Review table directly and produces identical output whether reviews came from Google Business Profile, Yelp, Trustpilot, or any future review source
- For each location, the system calculates three metrics per day across the full date range from earliest to latest review date: dailyReviewCount (reviews with reviewDate on that exact day), totalReviews (rolling count of all reviews up to end of that day), averageRating (rolling average of all ratings up to end of that day)
- All three metrics are persisted as Metric rows keyed as: BUSINESS_REVIEW_DAILY_COUNT, BUSINESS_REVIEW_TOTAL_COUNT, BUSINESS_REVIEW_AVERAGE_RATING
- Metrics are stored at location level (externalLocationId populated) — one row per metric key per day per location
- If no reviews exist for a location, no metrics are written and a warning is logged
- Calculation is triggered after any review sync completes — it is not coupled to a specific platform sync; any sync that writes to the Review table should trigger recalculation for the affected locations
- Existing metric rows for BUSINESS_REVIEW_* keys are deleted and recalculated on each run (rebuild model) until upsert-based incremental calculation is implemented
- averageRating values are stored as floats rounded to 2 decimal places

## Story 516 — Sync Google Search Console Data

As a client user, I want my Google Search Console data synced daily so that organic search performance metrics are available alongside my paid advertising and revenue data for correlation analysis.

- System fetches data using the Google Search Console API (webmasters v3, searchanalytics.query endpoint) authenticated via Google OAuth2 with webmasters.readonly scope — reuses the same Google OAuth token as GA4 and Google Ads
- Data is fetched per site URL (googleConsoleSiteUrl) configured per customer in config.json; customers without a site URL are skipped
- Two API calls are made per sync: one with no dimensions (overall aggregate for the period) and one with dimensions: ['date'] (daily breakdown)
- Core metrics synced per day: clicks, impressions, ctr (click-through rate), position (average search position)
- Daily metrics use the date key from the API response; overall/aggregate metrics have no date key and default to current date — KNOWN BUG: overall metrics should not be stored without a valid date anchor
- Metrics are stored via upsert keyed on (customerName, platformExternalId, externalLocationId, metricKey, date) — re-runs are safe and idempotent, unlike the other ad platform integrations which use insert
- ARCHITECTURAL NOTE: Unlike other integrations, the fetcher writes directly to the database internally rather than returning raw data to a separate formatter/index layer — this is inconsistent with the rest of the integration architecture and should be refactored
- Dimension-scoped metric keys are formatted as '{metricKey}_{dimension}' (e.g., 'clicks_date'); overall metric keys are unscoped (e.g., 'clicks')
- Token expiry is checked before each API call; if expired, a refresh is attempted using the stored refresh token; if refresh fails, the existing token is used and the API call proceeds anyway
- On first sync, backfill window is determined by the service layer (consistent with other integrations at 548 days); subsequent syncs fetch from day after last stored metric date
- Sync failures are logged with full error context including siteUrl, customerName, and dateRange and surfaced in Sync Status and History

## Story 517 — Sync Google Business Profile Performance Metrics

As a client user, I want my Google Business Profile engagement metrics synced daily so that visibility and interaction data (impressions, calls, direction requests, website clicks) are available alongside my other platform data for correlation analysis.

- System fetches data using the Google Business Profile Performance API v1 (businessprofileperformance, locations.fetchMultiDailyMetricsTimeSeries endpoint) authenticated via Google OAuth2
- Data is fetched per location ID listed in customerConfig.includedLocations, scoped under the customer's googleBusinessAccountId
- The following metrics are fetched as daily time series: BUSINESS_IMPRESSIONS_DESKTOP_MAPS, BUSINESS_IMPRESSIONS_DESKTOP_SEARCH, BUSINESS_IMPRESSIONS_MOBILE_MAPS, BUSINESS_CONVERSATIONS, BUSINESS_DIRECTION_REQUESTS, CALL_CLICKS, WEBSITE_CLICKS, BUSINESS_BOOKINGS, BUSINESS_FOOD_ORDERS, BUSINESS_FOOD_MENU_CLICKS
- Metrics are stored at location level (externalLocationId populated) with platformServiceType 'mybusiness' — one row per metric key per day per location
- On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date for that location
- Date arithmetic for the API call offsets the start date by +1 day — this is intentional to avoid re-fetching the last stored date
- Metric values are stored as integers (parseInt); null or missing values are stored as 0
- Location details (title, storeCode) are fetched per location during sync to generate the metric label
- Sync uses prisma.metric.create (insert not upsert) — re-running without clearing existing data will cause unique constraint violations; KNOWN LIMITATION: should be migrated to upsert consistent with the GSC integration
- Per-customer failures are caught and logged but do not halt processing of other customers; a summary of successes and failures is returned
- This integration is distinct from the GMB Reviews integration (story 513) — both use the same account and location config but call different APIs and store different data under different platformServiceType values ('mybusiness' vs 'mybusiness-reviews')

## Story 518 — Sync QuickBooks Account Transaction Data

As a client user, I want my QuickBooks income account data synced daily so that credit transactions (money coming into the business) are available as a metric for correlation analysis against my marketing activity.

- System connects to QuickBooks via the OAuth token established in the Connect Financial Platform via OAuth story (435) — no separate auth flow
- Data is fetched per income account selected by the user during OAuth connection setup; multiple selected accounts are each synced independently
- For each account, the system fetches debit and credit transaction totals aggregated by day using the QuickBooks Reports or Transactions API
- Credits (money in) are stored as the primary metric — this represents revenue flowing into the account and is the target variable for correlation analysis
- Debits (money out) are also stored as a separate metric so spend patterns can optionally be correlated as well
- Each metric is stored as a daily aggregate value — individual transactions are not stored, only the sum of credits and sum of debits per account per day
- Metric keys are: QUICKBOOKS_ACCOUNT_DAILY_CREDITS and QUICKBOOKS_ACCOUNT_DAILY_DEBITS
- platformExternalId is set to the QuickBooks account ID; externalLocationId is null (financial data has no location concept)
- On first sync, system backfills up to 548 days of historical data; subsequent syncs fetch from the day after the last stored metric date
- Days with no transactions are stored as zero-value records rather than gaps, to preserve continuity for correlation calculations
- Sync failures are logged with full error context including accountId, customerName, and dateRange and surfaced in Sync Status and History

## Story 519 — Connect Google Business Profile via OAuth

As a client user, I want to connect my Google Business Profile account(s) via OAuth so that the system can access my business locations and sync reviews and performance metrics across all of my GMB properties.

- User can initiate OAuth flow for Google Business Profile from the integrations settings page
- OAuth flow requests the following scopes: https://www.googleapis.com/auth/business.manage (or readonly equivalent) and reuses the existing Google OAuth token if already connected for Ads/GA4
- After successful authentication, user is presented with a list of all Google Business Profile accounts they have access to (fetched from accounts.list API)
- User can select ONE OR MORE GMB accounts — multi-select is required as a single business may have locations spread across multiple GBP accounts
- Each selected account is displayed with its account name and account ID for clarity
- Selected GMB account IDs are saved to the customer's platform integration config as an array (googleBusinessAccountIds — plural)
- If user previously connected a single googleBusinessAccountId (legacy singular field), migration path shows that account pre-selected and prompts confirmation
- User can return to this settings page later to add or remove GMB accounts without re-authenticating via OAuth
- Integration is saved only after at least one account is selected and confirmed
- Failed OAuth attempts show clear error messages
- User sees confirmation showing how many GMB accounts are connected and a prompt to proceed to location selection

## Story 520 — Fetch and Select Google Business Profile Locations Across Multiple Accounts

As a client user, I want the system to fetch and display all locations across my connected Google Business Profile accounts so that I can select which locations to include in syncing, with full support for customers who have locations spread across multiple GBP accounts.

- System fetches all locations across all configured googleBusinessAccountIds (plural) — iterates over the array and calls accounts/{accountId}/locations for each
- Locations are fetched using the Google Business Profile API v1 (mybusinessbusinessinformation or mybusiness v4) with fields: name, title, storeCode, storefrontAddress, websiteUri, regularHours, primaryCategory
- Pagination is handled — system follows nextPageToken until all locations are retrieved for each account
- All locations from all accounts are merged into a single flat list for display and selection
- User is presented with the full location list and can select which locations to include in syncing (includedLocations config)
- Each location row shows: account name (for disambiguation), location name/title, store code if present, and address
- Selected location IDs are stored in customerConfig.includedLocations as an array, prefixed with their accountId for unambiguous reference across multiple accounts
- User can update location selection at any time without re-authenticating
- If a location disappears from the API (e.g. deleted or access revoked), it is flagged in the UI rather than silently removed from sync config
- Sync jobs for reviews (story 513) and performance metrics (story 517) are updated to iterate over all accounts in googleBusinessAccountIds — not just a single googleBusinessAccountId
- Backfill behavior for newly added locations matches existing behavior: 548 days on first sync