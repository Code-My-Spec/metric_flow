# QA Story Brief: Agency Plan Management (Story 546)

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

No additional seeds needed. The plans page starts empty and plans are created through the UI.

## Setup Notes

This story requires the `billing_plans` database table to exist. If migrations haven't been run, the page will error. Also, plan creation requires a connected Stripe account — without one, the form will be disabled and show a warning.

## What To Test

### 1. Plan creation form visible (criterion 5007)
- Navigate to `http://localhost:4070/agency/plans`
- Verify page shows "Subscription Plans" heading
- Verify a plan creation form exists with Name, Price, Interval fields
- Fill in name "Pro Plan" and price "4999", submit
- Verify the plan appears in the list
- Screenshot evidence

### 2. Stripe sync on plan creation (criterion 5008)
- After creating a plan, check if a Stripe Price ID appears in the plans table
- If Stripe is not connected, verify the warning message appears
- Screenshot evidence

### 3. Update plan pricing (criterion 5009)
- Click Edit on an existing plan (`[data-role=edit-plan]`)
- Change the price and submit
- Verify the updated price appears in the list
- Screenshot evidence

### 4. Deactivate a plan (criterion 5010)
- Click Deactivate on an existing plan (`[data-role=deactivate-plan]`)
- Confirm the deactivation
- Verify the plan shows "Inactive" badge
- Screenshot evidence

### 5. Plans scoped to agency (criterion 5011)
- As a direct user, navigate to `/subscriptions/checkout`
- Verify no agency-specific plans are shown
- Screenshot evidence

### 6. Plans list with status (criterion 5012)
- Navigate to `/agency/plans`
- Verify the table shows Name, Price, Interval, Stripe Price ID, Status columns
- Verify active plans show "Active" badge
- Screenshot evidence

## Result Path

`.code_my_spec/qa/546/result.md`
