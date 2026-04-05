# QA Story Brief: Agency Customer Subscription Dashboard (Story 549)

## Tool

web (Vibium MCP browser automation)

## Auth

```
mcp__vibium__browser_launch(headless: true)
mcp__vibium__browser_navigate(url: "http://localhost:4070/users/log-in")
mcp__vibium__browser_scroll_into_view(selector: "#login_form_password")
mcp__vibium__browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
mcp__vibium__browser_fill(selector: "#user_password", text: "hello world!")
mcp__vibium__browser_click(selector: "#login_form_password button[name='user[remember_me]']")
mcp__vibium__browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

```
.code_my_spec/qa/scripts/start-qa.sh
```

## What To Test

### 1. View customer subscription list (criterion 5029)
- Navigate to `http://localhost:4070/agency/subscriptions`
- Verify page shows "Customer Subscriptions" heading
- Verify table columns: Customer, Plan, Status, Start Date
- Screenshot evidence

### 2. Summary stats (criterion 5030)
- On the subscriptions page, verify summary stats showing Active Subscribers and MRR
- Screenshot evidence

### 3. Cancel customer subscription (criterion 5031)
- Verify a Cancel action exists for active subscriptions
- Click cancel and confirm
- Screenshot evidence

### 4. Data scoped to agency (criterion 5032)
- Verify only the current agency's customer data is visible
- Screenshot evidence

### 5. Search and pagination (criterion 5033)
- Verify search input exists
- Verify pagination controls exist
- Screenshot evidence

### 6. Status badges (criterion 5034)
- Verify status badges display (Active, Past due, Cancelled, Trialing)
- Screenshot evidence

## Result Path

`.code_my_spec/qa/549/result.md`
