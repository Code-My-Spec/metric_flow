# QA Story Brief: Feature Gate — Paywall AI Features (Story 543)

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

### 1. Free users access Dashboard and Integrations (criterion 4983)
- Navigate to `http://localhost:4070/dashboard`
- Verify page renders without paywall
- Navigate to `http://localhost:4070/integrations`
- Verify page renders without paywall
- Screenshot both pages

### 2. Free users see paywall on AI features (criterion 4984)
- Navigate to `http://localhost:4070/correlations`
- Verify an upgrade/paywall prompt appears instead of correlation content
- Navigate to `http://localhost:4070/insights`
- Verify paywall appears
- Navigate to `http://localhost:4070/visualizations`
- Verify paywall appears
- Screenshot each page

### 3. Paywall shows plan and price (criterion 4985)
- On the paywall (any of correlations/insights/visualizations)
- Verify it shows a plan name and price (e.g., "$49.99/month")
- Screenshot evidence

### 4. Paywall CTA links to checkout (criterion 4986)
- On the paywall, verify a button/link pointing to `/subscriptions/checkout`
- Click the CTA and verify navigation to checkout page
- Screenshot evidence

### 5. Paid users see all features (criterion 4987)
- This requires a user with an active subscription — may need seed data
- Navigate to `/correlations` as a paid user
- Verify feature content loads without paywall
- Screenshot evidence

### 6. Server-side enforcement (criterion 4988)
- As a free user, navigate to `/correlations`
- Verify the page does NOT contain correlation result data
- Screenshot evidence

### 7. Reusable gate across routes (criterion 4989)
- Verify `/insights` shows the same paywall pattern as `/correlations`
- Screenshot both for comparison

### 8. Paywalled routes redirect or show 402 (criterion 4990)
- As a free user, directly access `/visualizations`
- Verify either a redirect to checkout/dashboard or an upgrade prompt with flash
- Screenshot evidence

## Result Path

`.code_my_spec/qa/543/result.md`
