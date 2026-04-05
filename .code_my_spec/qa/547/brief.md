# QA Story Brief: Agency Customer Billing (Story 547)

## Tool

web (Vibium MCP browser automation) for LiveView pages.
curl for webhook endpoint testing.

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

This story requires an agency user with Stripe Connect set up. Agency-specific seeds may need to be created.

## What To Test

### 1. Agency user association via invite (criterion 5013)
- Register a new user via an agency invite link
- Navigate to `/subscriptions/checkout`
- Verify the checkout page reflects agency context
- Screenshot evidence

### 2. Agency plans shown on checkout (criterion 5014)
- As an agency customer, navigate to `/subscriptions/checkout`
- Verify agency-specific plans are displayed, not the platform default
- Screenshot evidence

### 3. Checkout uses agency Stripe account (criterion 5015)
- Click subscribe button on checkout
- Verify redirect goes to Stripe checkout with agency's connected account
- Screenshot evidence

### 4. Successful payment stores subscription (criterion 5016)
- Visit checkout success URL
- Verify subscription status shows as active
- Screenshot evidence

### 5. Agency webhook events routed correctly (criterion 5017)
```bash
stripe trigger customer.subscription.created --api-key $(grep STRIPE_SECRET_KEY .env.dev | cut -d= -f2)
```
- Verify webhook returns 200

### 6. Subscription status synced via webhooks (criterion 5018)
```bash
stripe trigger customer.subscription.updated --api-key $(grep STRIPE_SECRET_KEY .env.dev | cut -d= -f2)
```
- Verify webhook returns 200

### 7. Disconnected agency preserves subscriptions (criterion 5019)
- Disconnect agency Stripe account
- Navigate to `/subscriptions/checkout`
- Verify warning about paused billing
- Screenshot evidence

### 8. Billing context immutable after subscription (criterion 5020)
- As a subscribed user, verify checkout page shows current billing context
- Screenshot evidence

## Result Path

`.code_my_spec/qa/547/result.md`
