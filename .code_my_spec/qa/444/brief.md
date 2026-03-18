# QA Story Brief

Story 444 — Default Canned Dashboards. Tests that the `/dashboards` page loads
for authenticated users and displays system-provided built-in dashboard templates
(Marketing Overview, Revenue Analysis, Platform Comparison).

## Tool

web (vibium MCP browser tools)

## Auth

Log in via the password form using the QA owner credentials:

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

## Seeds

Run the base seeds first (if not already done), then the story-444-specific seeds:

```bash
# Base seeds — creates qa@example.com user
mix run priv/repo/qa_seeds.exs

# Story 444 seeds — creates canned dashboards
mix run priv/repo/qa_seeds_444.exs
```

The seed script creates three built-in dashboards with `built_in: true`:
- "Marketing Overview"
- "Revenue Analysis"
- "Platform Comparison"

If the server is already running, use `--no-start`:

```bash
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds_444.exs
```

Verify seeds worked by navigating to `/dashboards` after login and checking for the "System Dashboards" section.

## What To Test

### Scenario 1 — Page loads for authenticated user

- Navigate to `http://localhost:4070/dashboards`
- Expected: Page loads with H1 "Dashboards" and subtitle "Your saved views and system dashboards"
- Expected: No redirect to `/users/log-in`
- Capture screenshot: `scenario_1_page_loads.png`

### Scenario 2 — Canned dashboards section is visible

- On the `/dashboards` page after login
- Expected: A "System Dashboards" section is present (`data-role="canned-dashboards"`)
- Expected: At least one card with `data-built-in="true"` is rendered
- Expected: Each card shows a "Built-in" badge and a "View" button
- Capture screenshot: `scenario_2_canned_dashboards_section.png`

### Scenario 3 — Marketing Overview template is displayed

- On the `/dashboards` page
- Expected: A card with the text "Marketing Overview" is visible
- Capture screenshot: `scenario_3_marketing_overview.png`

### Scenario 4 — Revenue Analysis template is displayed

- On the `/dashboards` page
- Expected: A card with the text "Revenue Analysis" is visible
- Capture screenshot: `scenario_4_revenue_analysis.png`

### Scenario 5 — Platform Comparison template is displayed

- On the `/dashboards` page
- Expected: A card with the text "Platform Comparison" is visible
- Capture screenshot: `scenario_5_platform_comparison.png`

### Scenario 6 — Multiple canned templates listed (template list)

- On the `/dashboards` page
- Expected: At least one element matching `[data-role='dashboard-card'][data-built-in='true']` is present
- Expected: All three named templates appear in the grid
- Capture screenshot: `scenario_6_multiple_templates.png`

### Scenario 7 — Unauthenticated user cannot access dashboards

- Clear cookies: `mcp__vibium__browser_delete_cookies()`
- Navigate directly to `http://localhost:4070/dashboards`
- Expected: Redirected to `/users/log-in` (not shown the dashboard templates)
- Capture screenshot: `scenario_7_unauthenticated_redirect.png`

### Scenario 8 — User dashboards section is present

- Log in and navigate to `/dashboards`
- Expected: A "My Dashboards" section with `data-role="user-dashboards"` is visible
- Expected: Empty state shows `data-role="empty-user-dashboards"` with "No dashboards yet" and a "Create your first dashboard" link (since qa@example.com has no user dashboards seeded)
- Capture screenshot: `scenario_8_user_dashboards_section.png`

### Scenario 9 — "New Dashboard" button is present

- On the `/dashboards` page
- Expected: A `data-role="new-dashboard-btn"` link with text "New Dashboard" navigates to `/dashboards/new`
- Capture screenshot: `scenario_9_new_dashboard_btn.png`

## Result Path

`.code_my_spec/qa/444/result.md`
