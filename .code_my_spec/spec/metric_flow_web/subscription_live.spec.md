# MetricFlowWeb.SubscriptionLive

Subscription and billing UI views.

## Type

live_context

## LiveViews

### SubscriptionLive.Checkout

- **Route:** `/subscriptions/checkout`
- **Description:** Subscription checkout flow for direct users and agency customers. Displays available plans, initiates Stripe Checkout sessions, and handles post-checkout confirmation. Routes payments to platform or agency Stripe account based on billing context.

## Components

None — the LiveView is self-contained.

## Dependencies

- MetricFlow.Billing
