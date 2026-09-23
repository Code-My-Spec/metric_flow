# QA Story 446 Brief: Select Goal Metrics for Correlation

## Tool

web (vibium MCP browser tools — all routes are LiveView)

## Auth

Log in as the QA owner user using the password form:

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
mcp__vibium__browser_get_url()   # verify — should be http://localhost:4070/
```

Credentials: `qa@example.com` / `hello world!`

## Seeds

The base seeds (`priv/repo/qa_seeds.exs`) provide the QA user and "QA Test Account". No story-specific seed script exists for story 446. The goal metrics page loads metric names from the database — the QA Test Account will likely have no metrics synced, which means the empty-state path will be exercised for most scenarios.

Verify seeds are in place by logging in successfully. If login fails, run seeds:

```bash
cd /Users/johndavenport/Documents/github/metric_flow
mix run priv/repo/qa_seeds.exs
```

Note: If the Phoenix server is already running, use the `--no-start` approach documented in the QA plan to avoid Cloudflare tunnel conflicts.

## Setup Notes

The `/correlations` index page (`CorrelationLive.Index`) does not currently contain a navigation link or button to `/correlations/goals`. The BDD spec for criterion 4102 checks for any of: `[data-role='configure-goals']`, `a[href='/correlations/goals']`, or page text matching "Goal Metrics", "Configure Goals", or "Set Goals". If none are found, the scenario will fail — this is expected behavior to flag for the team if the correlations index page is missing the goal configuration entry point.

The `/correlations/goals` page itself is fully implemented (`CorrelationLive.Goals`).

## What To Test

### Scenario 1: Access to goal metrics from the correlations menu (AC: "User can access Goal Metrics configuration from menu")

- Navigate to `http://localhost:4070/correlations`
- Capture a screenshot of the full correlations page
- Look for any of:
  - An element with `data-role="configure-goals"`
  - A link `a[href='/correlations/goals']`
  - Text containing "Goal Metrics", "Configure Goals", or "Set Goals"
- Expected: One or more of these should be present, giving the user a path to the goals configuration
- Note whether this entry point is present or absent — if absent, this is a bug (missing navigation to goal metrics from the correlations page)

### Scenario 2: Direct navigation to goal metrics page (AC: "User can access Goal Metrics configuration from menu")

- Navigate directly to `http://localhost:4070/correlations/goals`
- Capture a screenshot
- Expected: Page loads successfully, shows heading "Goal Metric" and subtitle "Choose the metric the correlation engine targets."
- Expected: A form is present with a goal metric select dropdown, a "Save Goal" button (`data-role="save-goal"`), and a "Cancel" button (`data-role="cancel"`)

### Scenario 3: Empty state when no metrics are synced (AC: "User can select one or more metrics as goals")

- On the goals page (`/correlations/goals`) with no synced data (expected for the QA account)
- Capture a screenshot
- Expected: Empty state message "No metrics available. Connect your integrations and sync data before configuring a goal." is visible
- Expected: A "Connect Integrations" link pointing to `/integrations` is displayed
- Expected: The "No metrics available — sync data first" placeholder option appears in the dropdown
- Expected: The "Save Goal" button is disabled
- Expected: The "Cancel" button is still present and enabled

### Scenario 4: Unauthenticated redirect

- Clear cookies to simulate a logged-out state:
  ```
  mcp__vibium__browser_delete_cookies()
  ```
- Navigate to `http://localhost:4070/correlations/goals`
- Expected: Redirect to `/users/log-in` (the page should not be accessible without authentication)
- Capture a screenshot of the login page after redirect

### Scenario 5: Cancel button navigates away

- Log in again after the unauthenticated test
- Navigate to `http://localhost:4070/correlations/goals`
- Click the "Cancel" button (`[data-role="cancel"]`)
- Expected: Navigated to `/correlations`
- Capture a screenshot confirming the correlations index page loaded

### Scenario 6: System stores goal metrics per account (AC: "System stores goal metrics per account" / "When user selects goal metrics, system queues correlation analysis")

This scenario requires metric data to be present. With the base QA seeds the account has no synced metrics, so the save flow cannot be exercised in full via the UI without additional setup. If metric data is available (e.g., from prior integration test runs), test:
- Navigate to `http://localhost:4070/correlations/goals`
- Select a goal metric from the dropdown
- Click "Save Goal"
- Expected: Flash message "Goal metric saved. Correlation analysis started." appears and page redirects to `/correlations`
- Capture a screenshot on the correlations index confirming the flash and redirect

If no metric data is available, document this as a limitation in the result and mark the scenario as skipped (not a bug — seeds do not include metric data).

### Scenario 7: Goal metric selection persists (AC: "User can modify goal metrics at any time")

- If goal data was saved in Scenario 6, navigate back to `http://localhost:4070/correlations/goals`
- Expected: The previously saved goal metric is pre-selected in the dropdown
- Capture a screenshot showing the pre-selected value

## Result Path

`.code_my_spec/qa/446/result.md`
