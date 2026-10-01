# Stories

## Story 8 — Agency Views and Manages Client Accounts

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
- Agency sees all accessible client accounts
- Client listing shows access level and origination status
- Agency switches between client accounts
- Navigation clearly displays the current client context
- Read-only agency user views reports and dashboards
- Read-only agency user cannot modify reports or integrations
- Account manager agency user modifies reports and integrations
- Account manager agency user cannot delete the account or manage users
- Admin agency user can do everything except delete the account
- Admin agency user cannot delete the account
- Admin agency user sees other users with access
- Non-admin agency user cannot see other users with access
- Originating agency sees the Originator badge

## Story 24 — Automated Correlation Analysis

As a client user, I want to see which marketing metrics correlate most with my goal metrics so that I can focus on activities that drive business results.

- System automatically calculates correlations between all metrics and selected goal metric(s)
- Correlations are calculated daily after data sync completes
- System tests multiple time lags (0-30 days) for each metric to automatically find optimal lag
- System selects lag with highest absolute correlation value for each metric
- Correlation calculations use daily aggregated data
- Only correlations meeting minimum data threshold are calculated (e.g., 30+ days of data)
- Correlation runs against ALL metrics (financial and marketing treated the same)
- System calculates correlations against a selected goal metric
- Correlations recalculate daily after sync completes
- System tests multiple time lags to find the best fit
- System selects the lag with the strongest correlation
- Correlation calculations use daily aggregated data
- Metric with insufficient history is excluded from correlation
- Correlation treats financial and marketing metrics uniformly

## Story 2 — User Login and Session Management

As a registered user, I want to log in securely so that I can access my account and data.

- User can log in with email and password
- Failed login attempts show clear error messages
- User session persists across browser tabs
- User can log out from any page
- Inactive sessions expire after a reasonable period
- User can use Remember me option for extended sessions
- User logs in with valid email and password
- Invalid credentials show a generic error without revealing which field was wrong
- Session persists when opening a new browser tab
- User logs out from any page
- Inactive session expires and requires re-login
- Remember me extends the session past the default timeout

## Story 49 — Agency Customer Billing: Route Subscription Payments to Agency Stripe Account

As a user who signed up under an agency, I want to subscribe to the agency's plan so that my payment goes directly to my agency, and I gain access to AI features under their account.

- When a user signs up via an agency invite link or referral token, they are associated with that agency (`agency_id` stored on the user record)
- Agency customers are shown the agency's available plan(s) on the paywall and checkout screens, not the platform's default plan
- Checkout for agency customers uses Stripe Checkout or Payment Element pointed at the agency's connected Stripe account (`stripe_account: agency.stripe_account_id`)
- On successful payment, the customer's `subscription_id`, `stripe_customer_id`, and `agency_id` are stored; the subscription is recorded as belonging to the agency's Stripe account
- Webhook events for agency customer subscriptions are routed and processed correctly using the agency's `stripe_account_id` to identify the source
- Agency customer subscription status is synced via webhooks just like direct users: `subscribed`, `past_due`, `canceled`
- If the agency's Stripe account becomes disconnected after a customer subscribes, the customer's subscription state is preserved but flagged; billing for new customers through the agency is paused
- A user's billing context (agency vs. direct) is immutable after subscription creation — changing it requires canceling and re-subscribing
- Signup via valid agency invite link stores agency_id
- Signup with expired or invalid referral token proceeds without agency association
- Agency customer sees the agency's plan at checkout
- Agency with no configured plans shows nothing to subscribe to
- Checkout session is created against the agency's connected Stripe account
- Checkout is blocked when the agency has no connected Stripe account
- Successful payment persists subscription_id, stripe_customer_id, and agency_id
- Webhook for an agency customer is routed using the agency's stripe_account_id
- Webhook carrying an unrecognized stripe_account_id is not applied to any agency
- Agency customer's subscription status syncs to past_due and canceled via webhooks
- Existing agency customer keeps access when the agency's Stripe account disconnects
- New customer billing is paused while the agency's Stripe account is disconnected
- Billing context cannot change without canceling and re-subscribing

## Story 7 — Manage User Access Permissions

As a client account owner, I want to manage which users have access to my account so that I can control who can view and modify my data.

- Client can view list of all users with access to their account
- List shows user or agency name, access level, date granted, and whether they are account originator
- Client can modify a user access level to upgrade or downgrade permissions
- Client can revoke a user access at any time
- When access is revoked, user immediately loses ability to view client data
- System logs all permission changes with timestamp and user who made change
- Account originator cannot have their access revoked, only ownership can be transferred
- Client views everyone with access to their account
- List shows name, access level, date granted, and originator flag
- Client upgrades a user's access level
- Client downgrades a user's access level
- Client revokes an agency's access to their account
- Revoked access is effective immediately
- Permission changes are logged with timestamp and actor
- Account originator's access cannot be revoked

## Story 4 — Agency Team Auto-Enrollment

As an agency account owner, I want to automatically add team members from my organization so that I do not have to manually invite each employee.

- Agency can configure domain-based auto-enrollment for their email domain
- Users who register with matching email domain are automatically added to agency account
- Auto-enrolled users get default access level set by agency admin
- Agency admin can view and manage all auto-enrolled team members
- Agency admin can disable auto-enrollment if desired
- Team members automatically inherit access to all client accounts the agency manages
- Agency configures domain-based auto-enrollment
- Domain already claimed by another agency is rejected
- Matching-domain registrant is auto-enrolled
- Subdomain registrant is not auto-enrolled
- Auto-enrolled user gets the configured default access level
- Agency admin views and manages auto-enrolled team members
- Agency admin disables auto-enrollment
- Auto-enrolled member inherits access to all agency client accounts

## Story 5 — Client Invites Agency or Individual User Access

As a client account owner, I want to invite agencies or individual users to access my account so that they can help manage my marketing data and reporting.

- Client can send email invitation to any email address (agency or individual)
- Invitation email contains secure link with expiration time of 7 days
- Invitee receives invitation in their email inbox
- Invitation includes client account name and access level being granted
- Client can specify access level in invitation: read-only, account manager, or admin
- Invitation link is single-use and invalidated after acceptance or expiration
- Client can view pending invitations and cancel them before acceptance
- Client can invite multiple agencies or users with different access levels
- Client sends an invitation to any email address
- Invitation email contains a secure link that expires in 7 days
- Invitee receives the invitation in their inbox
- Invitation shows the client account name and access level
- Client selects an access level when inviting
- Invitation link is single-use
- Client views and cancels a pending invitation
- Client invites multiple parties with different access levels

## Story 6 — Agency or User Accepts Client Invitation

As an invited user, I want to accept a client invitation so that I can access their account and provide services.

- User clicks invitation link and is taken to acceptance page
- If not logged in, user is prompted to log in or register
- Upon acceptance, user account is granted specified access level to client account
- User sees client account added to their account switcher or list
- Expired invitations show clear error message
- Already-accepted invitations cannot be reused
- If invitee is part of an agency, entire agency team gets access based on agency team structure
- Invitation link opens the acceptance page
- Logged-out invitee is prompted to log in or register
- Acceptance grants the specified access level
- Accepted client account appears in the account switcher
- Expired invitation shows a clear error
- Already-accepted invitation cannot be reused
- Agency invitee's team gains access per the agency's team structure

## Story 10 — Transfer Account Ownership

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
- Current owner initiates a transfer
- Non-owner cannot initiate a transfer
- Owner transfers to an existing user with access
- Owner invites a new email address as the new owner
- Transfer completes only after email confirmation
- Transfer wizard asks about copying and remaining as admin
- New owner verifies identity before accepting
- Unverified acceptance attempt is blocked
- Acceptance transfers ownership completely
- Previous owner's access reflects their selection
- White-label originator status optionally transfers with ownership
- All users are notified of the ownership change
- Ownership transfer is logged with both parties' confirmation

## Story 9 — User or Agency Self-Revokes Access

As a user with access to a client account, I want to revoke my own access so that I can cleanly end the relationship.

- User can revoke their own access from client account settings
- Confirmation prompt warns that this action cannot be undone
- After revocation, client account is removed from user account list
- Client is notified via email when user revokes their own access
- User cannot re-access account without new invitation from client
- Account originator cannot self-revoke and must transfer ownership first
- User revokes their own access from account settings
- Confirmation prompt warns the action is irreversible
- Revoked account disappears from the user's account list
- Client is notified when a user self-revokes
- Revoked user cannot re-access without a new invitation
- Account originator cannot self-revoke

## Story 11 — Connect Marketing Platform via OAuth

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
- User starts the OAuth flow for a supported platform
- OAuth flow opens in a popup or new tab
- Successful authentication returns user to platform selection
- User selects which accounts or properties to sync
- User changes synced accounts later without re-authenticating
- Incomplete OAuth leaves no saved integration
- User sees confirmation the integration is active
- Failed OAuth attempt shows a clear error message
- Agency cannot claim ownership of a client's platform connection

## Story 15 — Manual Sync Trigger (Admin)

As an admin user, I want to manually trigger a data sync so that I can debug integration issues or get fresh data on demand.

- Admin users see Sync Now button in integration settings
- Clicking sync triggers immediate data pull for that integration
- UI shows sync in progress with loading indicator
- Upon completion, user sees success message with timestamp and records synced
- If sync fails, error details are displayed
- Manual sync does not interfere with automated daily sync schedule
- Admin sees Sync Now button in integration settings
- Non-admin user does not see the Sync Now button
- Clicking Sync Now triggers an immediate data pull
- Sync in progress shows a loading indicator
- Sync completion shows success message with timestamp and record count
- Sync failure displays error details
- Manual sync doesn't disrupt the automated daily sync schedule
- Manual sync is rejected while a sync is already in progress

## Story 18 — View All Metrics Dashboard

As a client user, I want to see all my metrics from all platforms in one unified view so that I can understand my complete marketing and financial picture.

- User can access All Metrics dashboard showing data from all connected platforms
- Dashboard displays both marketing metrics and financial metrics with no distinction
- User can filter by platform, date range, or metric type
- User can select date range: last 7 days, 30 days, 90 days, all time, custom
- Date ranges default to last X days from yesterday to avoid incomplete current day
- Dashboard updates dynamically when filters change
- If no integrations connected, dashboard shows onboarding prompts
- All visualizations use Vega-Lite
- Dashboard shows data from all connected platforms
- Marketing and financial metrics appear together
- User filters the dashboard
- Filter combination with no matching data shows an empty state
- User selects a date range option
- Default date range excludes today
- Dashboard updates dynamically when a filter changes
- No connected integrations shows onboarding prompts
- Dashboard visualizations render with Vega-Lite

## Story 14 — Automated Daily Data Sync

As a system, I want to automatically sync data from all connected platforms daily so that user data stays fresh without manual intervention.

- Daily sync job runs automatically at the scheduled time
- Daily sync pulls new data from every active integration
- First sync after connecting backfills all available historical data
- Backfill is limited to what the platform's API allows
- Financial debits and credits are stored as metrics
- Daily sync retrieves metrics, review data, and financial data together
- Expiring OAuth token is refreshed automatically during sync
- Token refresh failure causes that integration's sync to fail
- Failed sync is retried up to 3 times with exponential backoff
- Sync is marked failed for the cycle once retries are exhausted
- Sync errors are logged with debugging detail
- Default date range excludes today

## Story 16 — Sync Status and History

As an admin user, I want to view sync history and status for each integration so that I can diagnose issues and understand data freshness.

- Each integration shows last successful sync timestamp
- Each integration shows next scheduled sync time
- User can view detailed sync history (last 30 syncs minimum)
- Sync history shows: timestamp, status (success or failure), records synced, and any error messages
- Failed syncs are highlighted with error details
- User can filter sync history by status (all, success, failed)
- Integration shows its last successful sync timestamp
- Integration that has never synced successfully shows no misleading timestamp
- Integration shows its next scheduled sync time
- Disconnected integration shows no next scheduled sync
- User views detailed sync history for an integration
- Sync history entry shows timestamp, status, records synced, and errors
- Failed sync is highlighted with its error details
- User filters sync history by status

## Story 17 — Handle Expired or Invalid OAuth Credentials

As a client user, I want to be notified when my platform credentials expire so that I can reconnect and resume data syncing.

- When OAuth token refresh fails, integration status changes to Needs Reconnection
- User sees warning indicator on integration in dashboard
- User receives email notification about expired credentials
- User can click Reconnect button to re-initiate OAuth flow
- After successful reconnection, sync resumes automatically
- System does not delete historical data when credentials expire
- Token refresh failure marks the integration Needs Reconnection
- Dashboard shows a warning indicator for the integration
- User is emailed about the expired credentials
- User reconnects via the Reconnect button
- Abandoned reconnect attempt leaves the integration in Needs Reconnection
- Sync resumes automatically after successful reconnection
- Historical data remains intact when credentials expire

## Story 12 — Connect Financial Platform via OAuth

As a client user, I want to connect my QuickBooks account so that my revenue data can be correlated with marketing metrics.

- User can initiate OAuth flow for QuickBooks
- OAuth flow authenticates user and grants access to financial data
- After successful authentication, user can select which income accounts to track
- User can select multiple income accounts, system will sum debits and credits
- Integration is saved only after successful OAuth completion
- User sees confirmation that QuickBooks is connected and ready to sync
- Failed OAuth attempts show clear error messages
- Financial data (debits and credits) becomes just another metric in the system for correlation
- User initiates the QuickBooks OAuth flow
- OAuth authenticates the user and grants financial data access
- User selects income accounts to track after authenticating
- Selecting multiple income accounts sums their debits and credits
- Integration saves only after OAuth completes
- Abandoned OAuth flow saves no integration
- User sees confirmation that QuickBooks is connected
- Failed OAuth attempt shows a clear error
- Financial data appears as a metric available for correlation

## Story 19 — Render Saved Visualizations in Dashboards and Reports

As a client user, I want to view rendered Vega-Lite visualizations within my dashboards and reports so that I can consume the charts I or my team have created.

- User can select from multiple chart types: line, bar, donut, Gantt, scatter, area, etc.
- User can switch chart types for any metric without losing filters or selections
- All charts render using Vega-Lite specifications
- Charts are interactive (hover for details, click to drill down where applicable)
- User can add multiple charts to same view for comparison
- Chart settings are saved with report when user saves
- User can view a saved Vega-Lite visualization rendered inline within a dashboard or report
- The visualization renders correctly across the supported chart types (bar, line, area, scatter, and any other valid Vega-Lite spec)
- If a visualization spec is missing or malformed, a clear error state is shown rather than a blank panel
- User can resize or expand a visualization within the report layout
- Visualizations sourced from the visualization library are displayed with their saved name and last-updated timestamp
- Visualizations are permanently bound to one or more metrics via a join table, not by embedding data in the spec
- The saved Vega-Lite spec is a template with no embedded data values — data is fetched and injected at render time from the bound metrics
- A visualization can display multiple metrics as separate series on the same chart
- User chooses among available chart types
- Switching chart type preserves filters and selections
- Common chart types render as valid Vega-Lite specs
- Less common chart types also render as valid Vega-Lite specs
- Charts respond to hover and click interactions
- Multiple charts are added to one view for comparison
- Saving a report persists each chart's settings
- Saved visualization renders inline in a dashboard
- Missing or malformed spec shows a clear error state
- Visualization bound to deleted metrics shows a clear error state
- User resizes a visualization within the report layout
- User expands a visualization within the report layout
- Library visualization shows its saved name and last-updated timestamp
- Visualization spec is data-free and populated at render time
- Same spec template renders different data for different metric bindings
- Visualization displays multiple metrics as separate series

## Story 21 — Default Canned Dashboards

As a client user, I want to access pre-built dashboard templates so that I can quickly get insights without building custom reports.

- System provides default dashboard templates (e.g., Marketing Overview, Revenue Analysis, Platform Comparison)
- User can select template and it auto-populates with their data
- Canned dashboards update automatically as new data syncs
- Canned dashboards use vega lite visualizations
- Canned dashboards include line charts shoting base metrics
- User browses available default templates
- Selecting a template auto-populates it with the user's data
- Template selected before any data has synced shows an empty state
- Canned dashboard reflects newly synced data automatically
- Canned dashboard charts render as Vega-Lite visualizations
- Canned dashboard includes a line chart of a base metric over time

## Story 23 — Select Goal Metrics for Correlation

As a client user, I want to specify which metrics are my business goals so that the system can identify what drives those outcomes.

- User can access Goal Metrics configuration from menu
- User can build up multiple goal metrics over time by creating separate single-metric goal configurations, one at a time (e.g., revenue account from QuickBooks) -- not a single multi-select control
- Selected goal metrics are highlighted or badged in metric lists
- User can modify goal metrics at any time
- System stores goal metrics per account
- When user selects goal metrics, system queues correlation analysis
- User opens Goal Metrics configuration from the menu
- User selects a single metric as a goal
- User creates multiple single-metric goals via separate goal configurations
- Goal metrics are highlighted in metric lists
- User modifies their goal metrics later
- Goal metrics persist per account
- Selecting goal metrics queues correlation analysis

## Story 20 — Create and Save Custom Reports

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
- User can insert a saved visualization from the visualization library as a component within a custom report, with the rendered chart appearing inline alongside other report elements
- User creates a report from a template
- User creates a report from a blank canvas
- User adds a visualization by selecting a metric and chart type
- User arranges visualizations in a layout
- User names and saves a report
- Saved report appears in the user's report list
- User edits a saved report
- User deletes a saved report
- Report includes metrics from multiple connected platforms
- Report charts render using Vega-Lite
- Report editor includes the canned Vega-Lite spec editor
- User inserts a saved visualization from the library into a report

## Story 31 — Client Views White-labeled Interface

As a client user, I want to see my agency branding when they have originated my account so that the experience feels professional and cohesive.

- When client accesses system via agency custom subdomain, they see agency branding
- Agency logo appears in navigation header
- Agency color scheme is applied throughout interface
- When client accesses via main domain, they see default branding
- If agency is account originator, white-labeling is always applied for that client
- Client can still customize their own dashboards regardless of white-labeling
- White-label branding does not affect functionality, only visual appearance
- Client sees agency branding via agency subdomain
- Unrecognized subdomain falls back to default branding
- Agency logo appears in the navigation header
- Agency color scheme applied throughout the interface
- Client sees default branding via the main domain
- White-labeling always applies for an agency-originated client
- Client customizes their own dashboard under white-labeling
- White-label branding changes appearance only, not functionality

## Story 27 — AI Insights and Suggestions

As a client user, I want to get AI-powered suggestions based on my correlation data so that I can make informed decisions about where to invest.

- User can enable AI Suggestions option in Smart mode
- AI analyzes correlation data and provides actionable recommendations (e.g., Increase Google Ads budget based on 0.85 correlation with revenue)
- Each chart or visualization can have an AI info button
- Clicking AI button shows context-specific insights or opens chat about that metric
- AI suggestions are based on correlation strength, trends, and business context
- User can provide feedback on suggestions (helpful or not helpful)
- AI learns from feedback to improve future suggestions
- User enables AI Suggestions in Smart mode
- AI provides an actionable recommendation from a strong correlation
- No suggestion is fabricated when no correlation is strong enough
- Chart displays an AI info button
- Clicking the AI button opens context-specific insights
- Suggestions reflect correlation strength, trend, and business context together
- User marks a suggestion as helpful or not helpful
- AI's future suggestions reflect prior feedback

## Story 50 — Stripe Webhook Handler: Subscription Lifecycle Sync

As the platform, I need a robust Stripe webhook handler that processes subscription lifecycle events for both direct users (platform account) and agency customers (connected accounts) so that subscription state stays accurate in real time.

- A Stripe webhook endpoint exists at a well-known URL and is registered in both the platform Stripe account and any agency connected accounts
- The handler verifies the `Stripe-Signature` header using the appropriate webhook secret (platform secret for direct users, agency-specific secret for agency customers)
- The handler processes at minimum: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
- On `payment_failed`, the user's subscription is marked `past_due` and they receive an email prompting them to update their payment method
- On `subscription.deleted`, the user is downgraded to free at the end of the billing period
- Webhook events are idempotent — duplicate deliveries do not double-process state changes
- All webhook events are logged with their Stripe event ID, type, processed status, and timestamp for auditability
- Webhook processing failures are captured and surfaced in an internal error log; Stripe retries are handled gracefully
- Valid signature is verified and processing continues
- Invalid or missing signature is rejected
- Recognized event updates local subscription state
- Unrecognized event type is acknowledged and ignored
- Payment failure marks subscription past_due and notifies the user
- Cancellation downgrades user at period end
- Duplicate delivery of the same event is a no-op
- Received event is logged with required fields
- Processing failure is logged and a Stripe retry succeeds cleanly
- Connected-account event is attributed to the correct agency
- Event with no identifiable account context is rejected

## Story 26 — View Correlation Analysis Results (Smart/AI Mode)

As a client user, I want to see AI-curated correlation insights so that I can quickly understand what matters most without analyzing raw data.

- In Smart/AI mode: analysis shows top 5 positive and top 5 negative correlations
- Only correlations above minimum threshold are shown (e.g., absolute value greater than 0.3)
- Results are presented with explanations (e.g., Google Ads spend shows strong correlation with revenue at 7-day lag)
- AI can highlight which correlations are most meaningful based on context
- User can still access full ranked list if desired
- Mode selection (Raw vs Smart) is saved per user preference
- Smart mode shows top 5 positive and top 5 negative correlations
- Only correlations above the minimum threshold are shown
- Fewer than five qualifying correlations shows only what qualifies
- Results are presented with a plain-language explanation
- AI highlights the most contextually meaningful correlations
- User can switch to the full ranked list
- Mode selection persists as a saved preference

## Story 25 — View Correlation Analysis Results (Raw Mode)

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
- User accesses correlation analysis from main navigation
- User toggles between Raw and Smart/AI modes
- Raw mode shows all correlations ranked strongest to weakest
- Each correlation row shows its full detail
- User sorts the list by correlation strength
- User sorts the list by platform
- Both positive and negative correlations are visible
- User filters the list by platform
- User selects a different time window for analysis
- Results update when the time window or filters change
- Insufficient data shows an explanatory message

## Story 28 — AI Chat for Data Exploration

As a client user, I want to chat with AI about my data so that I can ask questions and get insights in natural language.

- User can open AI chat from any report or visualization
- Chat context includes relevant data from current view
- User can ask questions like Why did my revenue drop last week
- AI has access to all metrics and correlation data to answer
- AI can suggest visualizations or reports based on questions
- Chat history is saved per user
- User can share chat insights with team members
- User opens AI chat from a report or visualization
- Chat context includes the current view's data
- User asks a natural-language question and gets an answer
- AI acknowledges when it cannot answer confidently
- AI draws on all metrics and correlation data to answer
- AI suggests a visualization based on a question
- Chat history persists per user across sessions
- User shares a chat insight with a team member

## Story 32 — Account Deletion (Owner Only)

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
- Owner sees the delete-account option
- Originator who is no longer owner cannot delete the account
- Typing the correct account name confirms deletion
- Typing the wrong account name blocks deletion
- Correct password re-entry allows deletion to proceed
- Incorrect password blocks deletion
- Owner sees a permanence warning before deleting
- All account data is removed after deletion
- All user access grants are revoked after deletion
- Owner receives a confirmation email after deletion
- Admin cannot delete the account

## Story 33 — Cross-Platform Metric Normalization and Mapping

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
- Canonical taxonomy exposes standard metrics
- Google Ads Clicks maps to canonical clicks
- Facebook Ads Link Clicks maps to the same canonical clicks
- Unmapped platform metric stored as platform-specific
- User views platform-to-canonical metric mappings
- Dashboard aggregates mapped metrics using canonical name
- Chart compares mapped metrics side-by-side across platforms
- Comparison warns of known semantic differences
- No warning shown when no semantic difference is known
- New integration adds mappings without altering existing canonical definitions
- Derived metric automatically extends to a newly mapped platform

## Story 37 — Sync Facebook Ads Data

As a client user, I want my Facebook Ads account data to be synced daily so that advertising spend, reach, and conversion metrics are available alongside my other platform data for correlation analysis.

- Sync fetches ad campaign performance data from the Facebook Marketing API for the ad account configured on the integration, using Facebook's own OAuth connection, separate from the Google integrations.
- An integration with no Facebook ad account configured fails to sync with a clear error rather than being silently skipped.
- Data is queried per day and, by default, per campaign; an ad-set-level breakdown is also available.
- Core metrics are stored daily: impressions, clicks, spend, CPM, CPC, CTR, conversions (purchases and off-site conversions), and conversion rate.
- On first sync, up to 548 days of historical data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history.
- Backfill returns less than 548 days of data when the account itself has less history available.
- Results are paginated automatically until all rows for the requested period have been retrieved.
- A non-numeric metric value in the API response is stored as zero rather than failing the whole sync.
- If the Facebook API rejects the request (expired or invalid authorization, insufficient permissions, an unrecognized ad account, or a rate limit) the sync for that integration fails with the API's error surfaced.
- A sync failure is retried automatically before being marked failed for the day; the failure and its cause are logged with enough detail to diagnose and are visible in Sync History.

## Story 29 — LLM-Driven Visualization Authoring

As a client user, I want to generate and iteratively refine Vega-Lite visualizations through an LLM chat interface so that I can build custom charts from my data without writing specs manually.

- User can enter natural language description of desired report
- LLM generates valid Vega-Lite specification
- User can preview generated visualization
- User can provide feedback to refine the visualization
- Generated report can be saved like any other custom report
- User can edit Vega-Lite spec directly if desired (advanced mode)
- System logs all LLM interactions for debugging
- User can open a visualization authoring workspace that shows three panels side-by-side: a chat interface, a Vega-Lite JSON spec editor, and a live rendered preview
- User can describe a visualization in natural language and the LLM generates an initial Vega-Lite spec using the available data fields for that account
- The generated spec is immediately loaded into the editor and rendered in the preview
- User can send follow-up messages in the chat to refine the visualization (e.g. change color, add a filter, switch chart type) and the LLM updates the spec accordingly
- Each LLM iteration updates the spec editor and re-renders the preview in real time
- User can also edit the Vega-Lite spec directly in the editor, with changes reflected in the preview without requiring an LLM round-trip
- The chat history persists for the duration of the authoring session
- User can name and save the visualization, making it available for inclusion in custom reports
- Saved visualizations appear in the visualization library accessible from the report builder
- User can open a visualization authoring workspace at /app/visualizations/:id/edit that shows three panels: a chat panel on the left, a live chart preview in the center, and a slide-out Vega-Lite JSON spec editor on the right (criterion 5047)
- User can describe a desired visualization in natural language via the chat panel; submitting the message dispatches a send_chat event that calls the LLM and streams the response back into the chat panel
- The LLM receives the full current Vega-Lite spec as context on every message, enabling iterative refinement without regenerating the spec from scratch
- Generated specs reference account metrics by name using Vega-Lite named data sources ("data": {"name": "metricName"}) rather than embedding raw data values, making specs portable reusable templates
- When the LLM generates or updates a spec, the system automatically creates or updates visualization_metrics join table entries to bind every referenced metric name to the visualization
- Multi-metric visualizations use a Vega-Lite layer with a separate named data source per metric
- The LLM receives relevant Vega-Lite v5 schema documentation as context, scoped to the chart type being requested, so it can produce valid specs for advanced chart types
- The chat panel renders the full conversation history — user messages and assistant responses — for the duration of the editing session
- When the LLM returns an updated spec, both the spec editor drawer and the live preview update automatically without a page reload
- User can edit the Vega-Lite spec directly in the spec editor drawer; changes are reflected in the live preview without requiring an LLM round-trip
- If the LLM produces a spec referencing a metric name not present in the account's available metrics, the chat panel surfaces an error identifying the unresolvable metric
- User can name and save the visualization, making it available for inclusion in custom reports (criterion 5054)
- Saved visualizations appear in the visualization library accessible from the report builder (criterion 5055)
- The LLM receives the current Vega-Lite spec as context with each follow-up message, enabling iterative editing of the same artifact
- The LLM generates specs using Vega-Lite named data sources (e.g. "data": {"name": "metricName"}) rather than embedding data values, consistent with the template storage format
- The system provides the account's available metric names to the LLM so it can reference valid data sources
- LLM generates an initial spec from a natural language request
- Generated spec loads into the editor and renders immediately
- Follow-up chat message refines the visualization in real time
- LLM failure during refinement surfaces an error rather than a silent no-op
- Generated visualization saves like any other custom report
- Direct spec edits reflect in the preview without an LLM round-trip
- LLM interactions are logged for debugging
- Authoring workspace shows chat, preview, and spec editor panels
- Reopening the workspace shows the full conversation history
- User names and saves a visualization for reuse in reports
- Saved visualization appears in the visualization library
- LLM edits the existing spec rather than regenerating from scratch
- Spec uses named data sources and binds metrics via the join table
- Multi-metric visualization renders as a layered chart with per-metric data sources
- LLM is given chart-type-scoped schema docs for advanced chart types
- Spec referencing an unresolvable metric surfaces a clear error

## Story 38 — Sync Google Business Profile Reviews

As a client user, I want my Google Business Profile reviews synced so that review volume and ratings are available as daily metrics alongside my marketing and financial data for correlation analysis.

- Sync fetches individual reviews from the Google Business Profile API for each location configured on the integration, using the account's Google OAuth authorization.
- An integration with no locations configured fails to sync with a clear error.
- Unlike the ad-platform and financial integrations, review sync does not use a backfill window -- the full available review history for each location is retrieved on every sync, paginating through results until no further pages remain.
- A location whose reviews can't be fetched is skipped without failing the sync for the integration's other locations.
- Sync failures are logged with enough detail to diagnose them and are visible in Sync History.

## Story 43 — Connect Google Business Profile via OAuth

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
- User initiates GBP OAuth from integrations settings
- Existing Google token is reused instead of re-prompting
- User sees all accessible GBP accounts after authenticating
- User selects multiple GMB accounts
- Selected account shows its name and ID
- All selected accounts are saved together
- Legacy single-account connection is pre-selected during migration
- User adds another account later without re-authenticating
- User removes an account later without re-authenticating
- Integration is not saved with zero accounts selected
- Failed OAuth attempt shows a clear error
- Confirmation shows account count and prompts location selection

## Story 39 — Calculate Rolling Review Metrics from Review Table

As a system, I want to derive daily rolling review metrics from the Review table regardless of source platform, so that review performance can be correlated with marketing and financial data across any platform that produces reviews.

- Rolling review metrics are computed from every review recorded for the account, regardless of which platform the review came from.
- For each day that has at least one review, three values are available: how many reviews arrived that day, the running total of all reviews to date, and the rolling average rating to date.
- These values are computed from the stored review data on demand, so they always reflect whatever reviews have been synced most recently, rather than being pre-calculated and stored separately.
- The same three values can be scoped to a given date range.
- An account with no reviews yet returns an empty result rather than an error.

## Story 36 — Sync Google Ads Data

As a client user, I want my Google Ads account data to be synced daily so that advertising spend and performance metrics are available alongside my other platform data for correlation analysis.

- Sync fetches Google Ads campaign performance data for the customer account configured on the integration, using the account's existing Google OAuth authorization -- no separate Google Ads connection step is required.
- An integration with no Google Ads customer ID configured fails to sync with a clear error rather than being silently skipped.
- Data is queried per day and, by default, per campaign; an ad-group-level breakdown is also available.
- Core metrics are stored daily: impressions, clicks, cost, conversions, conversion value, click-through rate, and average cost-per-click. Cost figures are converted from the API's micro-currency units to standard currency units before storage.
- On first sync, up to 548 days of historical campaign data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history.
- Backfill returns less than 548 days of data when the account itself has less history available.
- If the Google Ads API rejects the request (expired authorization, insufficient permissions, an unrecognized customer, or a rate limit) the sync for that integration fails with the API's error surfaced.
- A sync failure is retried automatically before being marked failed for the day; the failure and its cause are logged with enough detail to diagnose and are visible in Sync History.

## Story 42 — Sync QuickBooks Account Transaction Data

As a client user, I want my QuickBooks income account data synced daily so that credit transactions (money coming into the business) are available as a metric for correlation analysis against my marketing activity.

- Sync fetches daily credit and debit totals for the QuickBooks income account configured on the integration, using the account's existing QuickBooks OAuth authorization -- no separate financial-platform connection step is required.
- An integration missing its QuickBooks company or income account configuration fails to sync with a clear error.
- Credits (money in) and debits (money out) for each day are stored as two separate daily metrics, so revenue and spend can each be correlated independently.
- A day with no transactions is stored as a zero-value record rather than leaving a gap, so correlation calculations have continuous daily data.
- On first sync, up to 548 days of historical transaction data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history.
- Backfill returns less than 548 days of data when the account itself has less history available.
- If the QuickBooks API rejects the request (expired authorization, insufficient permissions, or an unrecognized company) the sync for that integration fails with the error surfaced.
- Sync failures are logged with enough detail to diagnose them and are visible in Sync History.

## Story 44 — Fetch and Select Google Business Profile Locations Across Multiple Accounts

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
- All locations are fetched across accounts, including paginated results
- Locations from multiple accounts merge into one list
- User selects locations to include in syncing
- Location row shows account, name, store code, and address
- Same location ID under different accounts remains distinguishable
- User updates location selection later without re-authenticating
- Deleted or inaccessible location is flagged rather than silently dropped
- Reviews and performance metrics sync across all connected accounts
- Newly added location backfills 548 days on first sync

## Story 47 — Agency Stripe Connect: Onboard Agency's Own Stripe Account

As an agency admin, I want to connect my own Stripe account to the platform so that subscription payments from my customers flow directly into my Stripe account, not the platform's default account.

- An agency admin can navigate to a Billing or Settings page and initiate Stripe Connect onboarding
- The platform initiates a Stripe Connect OAuth flow (Standard or Express account) and redirects the agency to Stripe's onboarding UI
- On completion, the platform stores the agency's `stripe_account_id` and marks the agency as `stripe_connected: true`
- If the agency abandons onboarding, their account is marked `stripe_connected: false` and they can retry
- The agency dashboard shows Stripe connection status (connected / not connected / restricted)
- An agency can disconnect their Stripe account; disconnection is reflected immediately and existing customer subscriptions are flagged for review
- If an agency is not Stripe-connected, their customers cannot be billed through the agency and are prompted to use the platform's default billing instead
- Agency Stripe connection state is stored on the `Agency` schema with `stripe_account_id`, `stripe_connect_status`, and `stripe_onboarded_at` fields
- Agency admin opens Connect Stripe from Billing settings
- Non-admin agency member cannot initiate Stripe connect
- Connect creates an Express account and redirects to Stripe
- Stripe account creation call fails
- Completed onboarding stores account id and marks connected
- Returning account is incomplete or restricted
- Agency admin abandons onboarding and can retry
- Dashboard reflects connection status
- Disconnecting Stripe takes effect immediately
- Disconnect request to Stripe fails
- Disconnecting flags existing subscriptions for review
- Customers of a non-connected agency are billed via platform default
- Agency schema carries Stripe connection fields through the lifecycle

## Story 48 — Agency Plan Management: Create Custom Subscription Plans

As an agency admin, I want to create and manage subscription plans for my customers with my own pricing so that I have full control over what I charge for access to MetricFlow under my agency.

- Agency admins can define one or more subscription plans within their agency, specifying a name and monthly price
- When creating a plan, the platform creates a corresponding Stripe Product and Price on the agency's connected Stripe account (using the agency's `stripe_account_id`)
- Agency admins can update plan pricing; the platform creates a new Stripe Price and marks the old one as inactive
- Agency admins can deactivate a plan; existing subscribers remain on the plan until they cancel or are migrated
- Agency plans are scoped to the agency and not visible to other agencies or direct users
- The agency settings UI lists all active plans with their Stripe Price IDs and status
- Agency admin creates a new plan
- Plan name cannot be blank
- Plan price must be positive
- Plan creation provisions a Stripe Product and Price
- Plan creation blocked without a connected Stripe account
- Updating plan price rotates the Stripe Price
- Deactivating a plan stops new signups but keeps existing subscribers
- Another agency's admin cannot see or select this plan
- Agency settings lists active plans with Stripe Price ID and status

## Story 51 — Agency Admin: Customer Subscription Management Dashboard

As an agency admin, I want to see and manage all my subscribed customers in one place so that I have visibility into my revenue and can take action on individual accounts.

- Agency admins can view a list of all customers subscribed under their agency with their subscription status, plan, and subscription start date
- Agency admins can see total active subscribers and MRR in a summary view (calculated from local data, not a live Stripe API call)
- Agency admins can cancel a specific customer's subscription, which triggers a cancel-at-period-end via the Stripe API on the agency's connected account
- Agency admins cannot see or modify other agencies' customer data
- The customer list paginates and is searchable by name or email
- Subscription status badge reflects real-time synced state: active, past_due, canceled, trialing
- Agency admin views their customer list with status, plan, and start date
- Summary view shows active subscribers and MRR from local data
- Agency admin cancels a customer's subscription at period end
- Canceling an already-canceled subscription is a no-op
- Agency admin cannot view another agency's customers
- Customer list paginates when there are more customers than fit one page
- Agency admin searches the customer list by name or email
- Status badge reflects the synced subscription state

## Story 22 — View and Navigate Saved Reports

As a client user, I want to access my saved reports easily so that I can review important metrics regularly.

- User can view list of all saved reports
- Reports are sorted by last modified date
- User can search reports by name
- Clicking report opens it in full view
- User can set report as favorite for quick access
- User can duplicate reports to create variations
- Report maintains selected date range from last viewing
- User views their list of saved reports
- Reports list is sorted by last modified date
- Searching by name filters the reports list
- Search with no matching reports shows an empty result
- Clicking a report opens its full view
- User favorites a report for quick access
- User duplicates a report to create a variation
- Reopening a report restores its last-viewed date range

## Story 1 — User Registration and Account Creation

As a new user, I want to register for an account so that I can access the reporting platform and manage my marketing data.

- User can register with email and password
- Email verification is required before account activation
- User is prompted to create an account name during registration
- Account type is specified during registration (Client or Agency)
- User who creates the account becomes the originator and default owner
- After verifying their email via the confirmation link, the user is logged in and directed to the onboarding flow
- Registration form validates email format and password strength
- Duplicate email addresses are rejected with clear error message
- User registers with a valid email and password
- New account is inactive until email is verified
- Verification link activates the account
- User is prompted for an account name during registration
- Selecting Client creates a Client account
- Selecting Agency creates an Agency account
- Registering user becomes the account's default owner
- User lands in onboarding already logged in, immediately after completing email verification (not immediately after submitting the registration form)
- Invalid email format or weak password blocks registration
- Registering with an email already in use is rejected

## Story 54 — Post-Registration Onboarding Welcome

As a newly registered user, I want to land on a welcome/onboarding screen right after signing up so that I know my account was created and can get started.

_No acceptance criteria._

## Story 13 — View and Manage Platform Integrations

As a client user, I want to view all my connected platforms so that I can manage my integrations and understand what data is being synced.

- User can view list of all connected integrations (marketing and financial)
- Each integration shows platform name, connected date, and sync status
- User can see which ad accounts, properties, or income accounts are selected for each integration
- User can modify selected accounts without re-authenticating
- User can disconnect or remove an integration
- Disconnecting shows warning that historical data will remain but no new data will sync
- User can reconnect a previously disconnected platform
- All integrations treated uniformly with no special QuickBooks UI
- Integrations list includes marketing and financial platforms together
- Integration entry shows name, connected date, and sync status
- Broken connection shows an error sync status
- Selected accounts are visible per integration
- Modify selected accounts without re-authenticating
- Modifying selection fails when platform access has been revoked
- Disconnect an integration
- Disconnect warning explains data retention
- Reconnect a disconnected platform
- Reconnect attempt fails when authorization is not granted
- QuickBooks uses the same integration UI as marketing platforms

## Story 30 — Agency White-label Configuration

As an agency account owner, I want to configure white-label branding for my agency so that clients see my brand when accessing reports.

- Agency can upload custom logo (supports PNG, JPG, SVG)
- Agency can set custom color scheme (primary, secondary, accent colors)
- Agency can configure custom subdomain (e.g., reports.andersonthefish.com)
- Changes preview in real-time before saving
- Agency can reset to default branding
- White-label settings are stored at agency account level
- Custom subdomain requires DNS verification before activation
- No Anderson Analytics branding visible on white-labeled instances
- Agency uploads a supported logo format
- Unsupported logo file type is rejected
- Agency sets a custom color scheme
- Agency configures a custom subdomain
- Subdomain already claimed by another agency is rejected
- Changes preview in real time before saving
- Agency resets branding to default
- White-label settings apply account-wide
- Subdomain activates once DNS verification succeeds
- Subdomain stays inactive while DNS verification is unresolved
- White-labeled instance shows no Anderson Analytics branding

## Story 45 — Feature Gate: Paywall AI Features for Free Users

As a free user, I should have access to the Dashboard and Integrations pages but be blocked from AI-powered features (Correlations, Intelligence, Visualizations) with a clear upgrade prompt so I understand the value of upgrading.

- Free users can access the Dashboard and all Integrations pages without restriction
- Free users who navigate to Correlations, Intelligence, or Visualizations see a paywall/upgrade modal instead of the feature content
- The paywall UI clearly communicates which plan unlocks AI features and the monthly price
- A CTA on the paywall routes the user to the subscription checkout flow
- Paid users and agency customers with active subscriptions see all features without restriction
- Feature access is enforced server-side — gating cannot be bypassed by manipulating client state
- A helper function or plug (e.g. `require_subscription`) is reusable across all paywalled routes
- Paywalled routes return 402 or redirect with a flash message when accessed via direct URL by free users
- Free user has full access to Dashboard and Integrations
- Free user sees a paywall instead of AI feature content
- Paywall states the unlocking plan and its price
- Paywall CTA routes to subscription checkout
- Subscribed direct user sees full AI feature content
- Agency customer keeps AI access while their subscription is flagged but still subscribed
- Past_due subscription is treated as inactive and re-paywalled
- Client-side tampering does not grant access to AI features
- The same gate blocks every AI route consistently
- Direct URL access to a paywalled route is blocked for free users

## Story 35 — Sync Google Analytics 4 Data

As a client user, I want my Google Analytics 4 property data to be synced daily so that website traffic and engagement metrics are available alongside my marketing spend and revenue data for correlation analysis.

- System fetches GA4 data using the Google Analytics Data API v1 (runReport endpoint), not the Universal Analytics API
- Data is fetched per GA4 property selected during OAuth connection
- System syncs the following GA4 metrics as core daily values: activeUsers, active7DayUsers, active28DayUsers, newUsers, engagedSessions, sessions, userEngagementDuration, screenPageViews, eventCount, keyEvents, scrolledUsers
- Each metric is stored as a daily time-series value keyed to the property and client account
- On first sync, system backfills up to 548 days of historical GA4 data (approximately 18 months); on subsequent syncs, fetches from the day after the last stored metric date
- Subsequent daily syncs fetch data for yesterday only (avoids incomplete current-day data)
- System handles GA4 API quota limits with exponential backoff and retry (default quota: 10 requests/second/project)
- If GA4 API returns no data for a day (e.g., property had no traffic), a zero-value record is stored rather than a gap
- GA4 metrics are mapped to canonical metric names in the cross-platform metric taxonomy (e.g., GA4 'sessions' maps to canonical 'sessions')
- GA4-specific metrics that have no canonical equivalent are stored as platform-specific metrics labeled 'Google Analytics: [metric name]'
- Sync failures for a GA4 property are logged with the API error response and surfaced in Sync Status and History
- Data fetched is scoped to the date range dimension only — no other dimensions (e.g., source/medium) are stored at this stage
- Sync calls the GA4 Data API v1 runReport endpoint
- Sync fetches data for the OAuth-selected GA4 property
- Sync stores all defined core GA4 metrics daily
- Missing core metric for a property does not fail the whole sync
- Metric is stored keyed to property and client account
- First sync backfills up to 548 days of history
- Backfill returns less than 548 days when GA4 has less history available
- Subsequent sync fetches only yesterday's data
- GA4 quota limit triggers backoff and retry that succeeds
- No-traffic day stores a zero-value record instead of a gap
- GA4 metric is mapped to its canonical name
- GA4-only metric is stored with a platform-specific label
- GA4 sync failure is logged and surfaced in Sync Status and History
- Stored data is scoped to date only, with no other dimensions

## Story 40 — Sync Google Search Console Data

As a client user, I want my Google Search Console data synced daily so that organic search performance metrics are available alongside my paid advertising and revenue data for correlation analysis.

- Sync fetches organic search performance data from the Google Search Console API for the site configured on the integration, using the account's existing Google OAuth authorization -- the same connection used for Google Ads and Google Analytics.
- An integration with no site configured fails to sync with a clear error rather than being silently skipped.
- Core metrics are stored daily: clicks, impressions, click-through rate, and average search position.
- Results are paginated automatically until all rows for the requested period have been retrieved.
- On first sync, up to 548 days of historical data is backfilled, ending the day before today so an incomplete current day never shows as a dip; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history.
- Backfill returns less than 548 days of data when the site itself has less history available.
- If the token has expired and can't be refreshed, or the Search Console API rejects the request (insufficient permissions or an unrecognized site), the sync for that integration fails clearly with the error surfaced.
- Sync failures are logged with enough detail to diagnose them, including which site and date range were being synced, and are visible in Sync History.

## Story 3 — Multi-User Account Access

As an account owner, I want to invite team members (both inside and outside my organization) to my account so that multiple people can access our data with appropriate permissions.

- Account owner or admin can invite users to their account via email
- Each user has their own login credentials
- Users can have different access levels: owner, admin, account manager, read-only
- Access levels follow hierarchy: only owners can add owners, only admins can add admins, etc.
- Account owner can view all users in their account with their access levels
- Account owner or admin can modify user access levels
- Account owner or admin can remove users from the account
- All users on an account see the same data with account-level isolation
- Owner invites a new user by email
- Each team member has distinct login credentials
- Account has users across all four access levels
- Admin can invite another admin
- Account manager cannot grant admin access
- Owner views all account users and their access levels
- Owner or admin changes a user's access level
- Admin cannot modify another admin's or the owner's access level
- Owner or admin removes a user from the account
- The last remaining owner cannot be removed
- Users on the same account share the same data
- Users on different accounts cannot see each other's data

## Story 34 — Correct Aggregation of Derived and Calculated Metrics

As a client user, I want calculated metrics like cost-per-click or conversion rate to be aggregated correctly when viewed across time periods or platforms, so that I see mathematically accurate numbers rather than misleading averages of averages.

- System distinguishes between raw/additive metrics (e.g., clicks, spend, impressions) and derived/calculated metrics (e.g., CPC, CTR, conversion rate, ROAS)
- Derived metrics are defined by a formula referencing their component raw metrics (e.g., CPC = total spend / total clicks)
- When aggregating derived metrics across time periods (e.g., daily to weekly), system sums the component metrics first then calculates the derived value from the aggregated components
- When aggregating derived metrics across multiple platforms or ad accounts, system sums the component metrics first then calculates the derived value from the aggregated components
- System never averages a derived metric directly across rows - it always re-derives from aggregated components
- Derived metric definitions are stored as metadata and can be extended for new metric types
- If a component metric has missing data for a time period, the derived metric for that period reflects the gap rather than silently producing incorrect values
- Derived metrics display identically to raw metrics in dashboards and reports - the aggregation logic is transparent to the user
- System classifies metrics as raw or derived
- Derived metric is defined by its formula over component metrics
- Aggregating across time sums components before deriving
- Aggregating across platforms sums components before deriving
- Combined time and platform aggregation still re-derives rather than averaging nested values
- New derived metric types can be added via metadata
- A genuine data gap in a component metric shows as an incomplete derived value
- Derived metrics display identically to raw metrics

## Story 41 — Sync Google Business Profile Performance Metrics

As a client user, I want my Google Business Profile engagement metrics synced daily so that visibility and interaction data (impressions, calls, direction requests, website clicks) are available alongside my other platform data for correlation analysis.

- Sync fetches location engagement metrics -- search and maps impressions, conversations, direction requests, call clicks, website clicks, bookings, food orders, and food menu clicks -- from the Google Business Profile Performance API for each location configured on the integration.
- Performance metrics and review data are synced separately per location, using different Google Business Profile APIs.
- Metrics are stored daily, per location, per metric, so performance can be seen location by location as well as in aggregate.
- A missing or null metric value is stored as zero rather than leaving a gap.
- On first sync, up to 548 days of historical data is backfilled; subsequent daily syncs are intended to fetch only data since the last successful sync rather than re-fetching the full history.
- Backfill returns less than 548 days of data when the location itself has less history available.
- A location whose metrics can't be fetched is skipped without failing the sync for the integration's other locations.
- Sync failures are logged with enough detail to diagnose them and are visible in Sync History.