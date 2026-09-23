# QA Story Brief: Agency Stripe Connect (Story 545)

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

### 1. Navigate to Stripe Connect page (criterion 4999)
- Navigate to `http://localhost:4070/agency/stripe-connect`
- Verify "Stripe Connect" heading is displayed
- Verify a connect button is visible
- Screenshot evidence

### 2. Initiate Stripe Connect flow (criterion 5000)
- Click the connect button (`[data-role=connect-stripe]`)
- Verify redirect to Stripe onboarding or appropriate response
- Screenshot evidence

### 3. Stripe account stored after completion (criterion 5001)
- After completing onboarding, verify the page shows "Connected" status
- Screenshot evidence

### 4. Abandoned onboarding allows retry (criterion 5002)
- If onboarding was abandoned, verify the connect button is still available
- Screenshot evidence

### 5. Connection status display (criterion 5003)
- Verify status badges: Connected, Not connected, or Restricted
- Screenshot evidence

### 6. Disconnect Stripe account (criterion 5004)
- If connected, click disconnect button (`[data-role=disconnect-stripe]`)
- Verify status changes to "Not connected"
- Screenshot evidence

### 7. Unconnected agency billing fallback (criterion 5005)
- Navigate to `/subscriptions/checkout` as a user under an unconnected agency
- Verify platform billing is shown
- Screenshot evidence

### 8. Stripe state stored on schema (criterion 5006)
- Verify the Stripe Connect page reflects stored state correctly
- Screenshot evidence

## Result Path

`.code_my_spec/qa/545/result.md`
