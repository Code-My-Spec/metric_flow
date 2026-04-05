# QA Story Brief: Direct User Subscription (Story 544)

## Tool

web (Vibium MCP browser automation) for all LiveView pages and form interactions.
curl for the Stripe webhook endpoint (`/billing/webhooks`).

## Auth

Login via Vibium MCP browser tools:

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

Run the base QA seeds to create the test user:

```
.code_my_spec/qa/scripts/start-qa.sh
```

No additional story-specific seeds are required — the subscription plan should be seeded by the application or created via the checkout page.

## What To Test

### 1. Subscription plan visible on checkout page (criterion 4991)
- Navigate to `http://localhost:4070/subscriptions/checkout`
- Verify a plan is displayed with a name (e.g., "MetricFlow Pro"), monthly price, and a subscribe action
- Screenshot evidence

### 2. Free user sees paywall on AI features (criterion 4992)
- Navigate to `http://localhost:4070/correlations`
- Verify the page shows a paywall/upgrade prompt instead of correlation content
- Verify an "Upgrade" CTA is visible that links to checkout
- Navigate to `http://localhost:4070/accounts/settings`
- Verify the settings page shows a Subscription/Plan section with upgrade option
- Screenshot evidence for both pages

### 3. Checkout redirects to Stripe (criterion 4993)
- On the checkout page, click the subscribe/checkout button (`[data-role=subscribe-button]`)
- Verify the browser is redirected to a Stripe-hosted checkout URL
- Screenshot the redirect URL

### 4. Successful payment updates subscription status (criterion 4994)
- Navigate to `http://localhost:4070/subscriptions/checkout/success?session_id=test_session`
- Verify the page confirms subscription is active
- Navigate to account settings and verify subscription status shows "Active"
- Screenshot evidence

### 5. Stripe webhook processes subscription events (criterion 4995)
- Send a POST to `/billing/webhooks` with a `customer.subscription.created` event payload:

```bash
curl -X POST http://localhost:4070/billing/webhooks \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: test_signature" \
  -d '{"id":"evt_test_1","type":"customer.subscription.created","data":{"object":{"id":"sub_test","customer":"cus_test","status":"active","items":{"data":[{"price":{"id":"price_test"}}]},"current_period_start":1700000000,"current_period_end":1702592000}}}'
```

- Verify 200 response status

### 6. Subscription cancellation handled gracefully (criterion 4996)
- Send a POST to `/billing/webhooks` with a `customer.subscription.deleted` event payload
- Verify 200 response status
- Navigate to account settings and verify the user is shown as free/cancelled

### 7. View current plan and billing status (criterion 4997)
- Navigate to `http://localhost:4070/accounts/settings`
- Verify the page displays current plan name and billing status (Free or Active)
- Screenshot evidence

### 8. Cancel subscription from account settings (criterion 4998)
- If user has an active subscription, navigate to `http://localhost:4070/accounts/settings`
- Verify a "Cancel subscription" option is visible
- Click cancel and verify confirmation prompt appears
- Screenshot evidence

## Result Path

`.code_my_spec/qa/544/result.md`
