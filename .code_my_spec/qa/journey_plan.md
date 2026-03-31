# QA Journey Plan

End-to-end QA journey plan. Defines user journeys through the app from empty instance to functioning software, with prerequisites and step-by-step scenarios.

## Prerequisites

- Phoenix server running: `mix phx.server` (port 4070)
- Database migrated: `mix ecto.migrate`
- QA seeds loaded: verify by logging in as `qa@example.com` / `hello world!` — if login fails, run `mix run priv/repo/qa_seeds.exs`
- Vibium browser automation available via MCP
- Dev mailbox accessible at `http://localhost:4070/dev/mailbox` for email verification
- Cloudflare tunnel active: `dev.metric-flow.app` → localhost:4070 (required for OAuth callbacks)

### Existing Data State

The QA database already has substantial real data belonging to `qa@example.com` (user_id 2):

**Integrations (6 connected):** google_ads, google_analytics, google_business, google_search_console, facebook_ads, quickbooks

**Metrics (79,567 rows across 47 metric names):**
- google_ads: 7 metrics, ~7,500 rows each (2024-09-16 to 2026-03-20)
- google_analytics: 6 metrics, ~940 rows each (2026-02-14 to 2026-03-17)
- google_business: 12 metrics including reviews, ~1,100 rows each (2024-09-19 to 2026-03-22)
- google_search_console: 4 metrics, ~1,600 rows each (2024-11-03 to 2026-03-19)
- facebook_ads: 8 metrics, ~62 rows each (single day 2024-09-16)
- quickbooks: 9 metrics including daily credits/debits (~1,100 rows) and summary metrics

**Sync history:** 14 entries across google_ads, google_business, google_search_console, quickbooks (mix of success and failed)

**Correlation jobs:** 5 completed jobs for account_id 14 ("Client Alpha"), all with 0 results — goal metrics chosen had insufficient data points (e.g., `gross_profit` with only 1 day of data)

**Accounts:** 27 accounts. `qa@example.com` is member of multiple accounts including "QA Test Account" (id 21) and several client accounts (Client Alpha, Client Beta, Client Read Only, Client Account Manager) with various roles.

**Key users:**
- `qa@example.com` (id 2) — owner of all integrations and metrics, member of many accounts
- `qa-member@example.com` — secondary test user
- `johns10@gmail.com` (id 1) — has 1 facebook_ads integration

This means the QA agent should expect to see real data in dashboards and integrations pages when logged in as `qa@example.com`. Dashboards should render charts with actual metric data, not empty onboarding prompts.

## Journeys

### Journey 1: New User Registration to First Dashboard

**Role:** New user (no existing account)

**Steps:**

1. Navigate to `http://localhost:4070/users/register`
2. Fill registration form: unique email (e.g. `qa-journey1-{timestamp}@example.com`), password (12+ chars, e.g. `hello world!`), account name, account type (select one)
3. Submit registration — verify redirect to confirmation/onboarding screen
4. Open dev mailbox at `http://localhost:4070/dev/mailbox`, find confirmation email, click magic link
5. Log in with registered email and password via `/users/log-in` (scroll to password form, `#login_form_password`)
6. Verify redirect to `/` or `/onboarding`
7. Navigate to `/dashboards` — verify "All Metrics" canned dashboard exists
8. Click into All Metrics dashboard — verify onboarding prompt shown (new user has no integrations)
9. Navigate to `/accounts` — verify account listed with owner role
10. Navigate to `/users/settings` — verify email and password change forms render
11. Log out via user dropdown — verify redirect to login page
12. Attempt to access `/dashboards` while logged out — verify redirect to `/users/log-in`

**Expected outcome:** User can register, confirm email, log in, see empty dashboard with onboarding prompt, access account settings, and log out. Auth guards prevent unauthenticated access.

### Journey 2: Account Administration and Team Management

**Role:** QA owner (`qa@example.com`) and QA member (`qa-member@example.com`)

NOTE: Re-run `mix run priv/repo/qa_seeds.exs` before this journey to reset role state. The QA database has accumulated role drift from prior test runs.

**Steps:**

1. Log in as `qa@example.com` / `hello world!` — verify redirect to `/`
2. Navigate to `/accounts` — verify "QA Test Account" listed (account_id 21); qa@example.com should be owner
3. Switch active account to "QA Test Account" if not already active
4. Navigate to `/accounts/members` — verify member list renders with role column
5. If qa-member@example.com is present, change their role — verify role updates in UI
6. Navigate to `/accounts/invitations/send` — verify invitation form renders with role select
7. Send invitation to a test email (e.g. `test-journey2@example.com`) with admin role
8. Verify invitation appears in pending invitations list
9. Cancel the pending invitation — verify it disappears from list
10. Navigate to `/accounts/settings` — verify account name and slug fields render
11. Edit account name — verify save succeeds
12. Clear cookies, log in as `qa-member@example.com` / `hello world!`
13. Navigate to `/accounts` — verify "QA Test Account" listed with their current role
14. Navigate to `/accounts/settings` — verify ownership transfer controls are NOT visible (not owner)
15. Clear cookies, log in as `qa@example.com` for subsequent journeys

**Expected outcome:** Owner can manage members, change roles, send/cancel invitations, and edit account settings. Non-owner sees appropriate restrictions.

### Journey 3: Integration Dashboard and Data Sync

**Role:** QA owner (`qa@example.com`) — has 6 connected integrations and ~80K metric rows

This journey tests the integration management and sync UI using existing real data. Do NOT attempt new OAuth flows — the tokens may be expired and OAuth requires interactive browser consent.

**Steps:**

1. Log in as `qa@example.com`
2. Navigate to `/integrations/connect` — verify OAuth provider cards shown (Google, Facebook, QuickBooks)
3. Verify providers show "Connected" status for Google, Facebook, and QuickBooks (all 6 integrations are under qa@example.com)
4. Navigate to `/integrations` — verify platform list shows data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks, Google Business Profile, Google Search Console)
5. Verify each platform shows connection status reflecting the existing integrations
6. Click into a connected platform (e.g. Google Ads) — verify detail view renders with sync status
7. Look for "Sync Now" button — if visible, note whether it's enabled or disabled (tokens may be expired)
8. Navigate to sync history page — verify history entries appear (expect ~14 entries: google_ads success, google_business mix of success/failed, google_search_console success, quickbooks success)
9. Verify history shows timestamp, status, and provider for each entry
10. Navigate to `/dashboards` — verify All Metrics dashboard renders with actual chart data (NOT the onboarding empty state)
11. Verify Vega-Lite chart renders with metric lines from the ~80K data points
12. Use platform filter — select a single platform (e.g. Google Ads) and verify chart updates to show only that platform's metrics
13. Use date range picker — change range and verify data updates
14. Verify data table below chart shows metric values

**Expected outcome:** Integration pages correctly reflect 6 connected providers. Sync history shows real entries. Dashboard renders Vega-Lite charts with real metric data from all platforms. Filters and date pickers work.

### Journey 4: Correlation Analysis and AI Insights

**Role:** QA owner (`qa@example.com`) — has metric data suitable for correlation

NOTE: Prior correlation jobs used goal metrics with too few data points (e.g. `gross_profit` with 1 day). For meaningful results, select a goal metric with deep history like `QUICKBOOKS_ACCOUNT_DAILY_CREDITS` (1,098 rows) or Google Ads `clicks` (7,531 rows).

**Steps:**

1. Log in as `qa@example.com`
2. Navigate to `/correlations/goals` — verify goal metric selection page renders
3. Select a goal metric with substantial data — prefer `QUICKBOOKS_ACCOUNT_DAILY_CREDITS` or a Google Ads metric (these have 500+ days of data, well above the 30-day minimum)
4. Verify selection saves and correlation job is queued
5. Navigate to `/correlations` — verify correlation results page renders
6. Check Raw mode — if correlation job completed with results, verify ranked list shows metric name, correlation coefficient, optimal lag, time period
7. If results show 0 (job still running or data mismatch), verify the "no results" or "running" state renders correctly
8. Toggle to Smart/AI mode — verify mode switch works and shows filtered top correlations (or appropriate empty state)
9. Navigate to `/ai/insights` — verify AI insights panel renders
10. If insights exist: verify recommendation cards show suggestion type and confidence; click helpful/not-helpful feedback
11. Navigate to `/ai/chat` — verify chat interface renders with session sidebar
12. Start a new chat session — type a question about metrics (e.g. "What are my top performing Google Ads metrics?")
13. Verify AI response streams in the conversation area
14. Navigate to `/ai/report-generator` — verify natural language report form renders
15. Enter a report description (e.g. "Show me Google Ads clicks over time") — verify Vega-Lite preview generates

**Expected outcome:** Goal metric selection works. Correlation analysis runs against real data. AI features (insights, chat, report generator) render and function. With proper goal metric selection, correlation results should be non-empty given the 500+ days of overlapping data.

### Journey 5: Agency White-Label and Multi-Client Access

**Role:** Agency owner (use existing accounts or create new)

NOTE: The database already has "QA Agency 454" (id 18) and various client accounts. `qa@example.com` has roles across multiple accounts (Client Alpha as admin, Client Beta as admin, Client Read Only as read_only, Client Account Manager as account_manager), making it ideal for testing account switching and role-based restrictions.

**Steps:**

1. Log in as `qa@example.com`
2. Navigate to `/accounts` — verify multiple accounts listed with different roles (expect: QA Test Account/owner, Client Alpha/admin, Client Beta/admin, Client Read Only/read_only, Client Account Manager/account_manager, and others)
3. Verify each account row shows account name, role, and account type
4. Switch active account to "Client Alpha" — verify navigation updates to show "Client Alpha" context
5. Navigate to `/accounts/members` — verify member list visible (qa@example.com is admin here)
6. Switch to "Client Read Only" — verify restricted UI (read_only role should hide management controls)
7. Switch to "Client Account Manager" — verify intermediate permissions (can modify reports/integrations but not manage users)
8. Switch back to a team account where qa@example.com is owner
9. Navigate to `/accounts/settings` — look for agency settings section (auto-enrollment, white-label)
10. If agency settings visible: configure auto-enrollment domain and white-label colors, verify save
11. Test invitation flow: send invitation from current account to a test email
12. Verify invitation appears in pending list
13. Switch between accounts several times — verify context persists and navigation reflects active account

**Expected outcome:** User can view and switch between multiple accounts with different roles. Role-based UI restrictions apply correctly per account. Agency settings render for team accounts where the user has sufficient permissions.

## Notes

The QA database contains real production-like data from actual OAuth integrations. Some OAuth tokens may be expired (check `expires_at` on integrations table). Expired tokens will cause "Sync Now" to fail or show "Needs Reconnection" status — this is expected behavior and tests Story 440 (Handle Expired or Invalid OAuth Credentials).

Correlation analysis requires overlapping date ranges between the goal metric and other metrics. Google Ads data (2024-09-16 to 2026-03-20) overlaps well with QuickBooks daily credits (2024-09-18 to 2026-03-20) and Google Business metrics (2024-09-19 to 2026-03-22). Google Analytics has a narrower range (2026-02-14 to 2026-03-17). Facebook Ads has only one day of data (2024-09-16) and will not produce meaningful correlations.

Journeys can be run independently. Journey 1 creates a fresh user and should not depend on existing state. Journeys 2-5 use `qa@example.com` and the existing data. Re-run seeds before Journey 2 if role state has drifted.
