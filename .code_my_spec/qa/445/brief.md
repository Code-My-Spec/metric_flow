# QA Story Brief

Story 445 — View and Navigate Saved Reports

Tests the `MetricFlowWeb.DashboardLive.Index` LiveView at `/dashboards`. The page shows two sections: system-provided canned dashboards and the authenticated user's own saved dashboards. Inline delete confirmation is the main user interaction implemented.

## Tool

web (vibium MCP browser tools)

## Auth

Log in as `qa@example.com` using the password form:

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

Run base seeds first, then the canned dashboard seeds:

```bash
# Verify server is up
curl -s -o /dev/null -w "%{http_code}" http://localhost:4070/users/log-in
# Expected: 200

# If login fails (user doesn't exist), run base seeds:
mix run priv/repo/qa_seeds.exs

# Run canned dashboard seeds (idempotent):
mix run priv/repo/qa_seeds_444.exs
```

The `qa_seeds_444.exs` script creates three canned (built-in) dashboards:
- "Marketing Overview"
- "Revenue Analysis"
- "Platform Comparison"

To test the user-owned dashboards section with real data (not just the empty state), create a dashboard through the UI by navigating to `/dashboards/new` after login, or rely on the empty-state scenario instead. The existing seeds do not create user-owned dashboards for `qa@example.com`.

## What To Test

### Scenario 1: Unauthenticated redirect (AC: list page requires auth)

- Navigate to `http://localhost:4070/dashboards` without logging in
- Expected: redirected to `/users/log-in` (HTTP 302 via curl or browser redirect)
- Verify with: `curl -s -o /dev/null -w "%{http_code}" -L http://localhost:4070/dashboards`
- Expected status: 200 (followed redirect to login page) — check final URL contains `/users/log-in`

### Scenario 2: Page loads and shows heading

- Log in as `qa@example.com`
- Navigate to `http://localhost:4070/dashboards`
- Screenshot the full page
- Verify: page title/heading "Dashboards" is visible (`h1` containing "Dashboards")
- Verify: subtitle "Your saved views and system dashboards" is visible
- Verify: "New Dashboard" button is present (`[data-role='new-dashboard-btn']` linking to `/dashboards/new`)

### Scenario 3: Canned dashboards section is visible

- On the dashboards page (after running `qa_seeds_444.exs`)
- Verify: `[data-role='canned-dashboards']` section is present
- Verify: heading "System Dashboards" is visible
- Verify: subtitle "Pre-built views ready to use" is visible
- Verify: dashboard cards are shown for "Marketing Overview", "Revenue Analysis", "Platform Comparison"
- Verify: each canned card has a `data-built-in="true"` attribute
- Verify: each canned card shows a "Built-in" badge
- Verify: each canned card has a "View" link (`[data-role='view-dashboard-{id}']`)
- Verify: no "Delete" button appears on canned dashboard cards

### Scenario 4: User dashboards section — empty state

- On the dashboards page with no user-owned dashboards created
- Verify: `[data-role='user-dashboards']` section is present
- Verify: heading "My Dashboards" is visible
- Verify: `[data-role='empty-user-dashboards']` is visible with text "No dashboards yet"
- Verify: "Create your first dashboard" link inside the empty state links to `/dashboards/new`

### Scenario 5: Create a user dashboard and verify it appears in the list

- Click "New Dashboard" (`[data-role='new-dashboard-btn']`) or navigate to `/dashboards/new`
- Fill in a dashboard name (e.g., "QA Revenue Dashboard") and save
- Navigate back to `/dashboards`
- Verify: "QA Revenue Dashboard" appears in the `[data-role='user-dashboards']` section
- Verify: the card has `data-built-in="false"`
- Verify: "View", "Edit", and "Delete" buttons/links are present on the user card

### Scenario 6: Inline delete confirmation flow

- On `/dashboards` with the "QA Revenue Dashboard" present from Scenario 5
- Click the "Delete" button (`[data-role='delete-dashboard-{id}']`)
- Verify: inline confirmation appears (`[data-role='delete-confirm-{id}']`) with "Are you sure?" text
- Verify: "Yes, delete" button (`[data-role='confirm-delete-{id}']`) is visible
- Verify: "Cancel" button (`[data-role='cancel-delete']`) is visible
- Click "Cancel"
- Verify: confirmation prompt disappears, dashboard card is still present

### Scenario 7: Confirm delete removes dashboard

- On `/dashboards` with a user-owned dashboard present
- Click "Delete" on the dashboard, then click "Yes, delete"
- Verify: dashboard card is removed from the list
- Verify: flash message "Dashboard deleted." appears
- Screenshot the result

### Scenario 8: Clicking "View" on a canned dashboard navigates to it

- On `/dashboards` with canned dashboards visible
- Click the "View" link on "Marketing Overview"
- Verify: browser navigates to `/dashboards/{id}` (URL changes)
- Screenshot the resulting page

## Result Path

`.code_my_spec/qa/445/result.md`
