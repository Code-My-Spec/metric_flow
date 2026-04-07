# Design Review

## Overview

Reviewed the MetricFlowWeb.SubscriptionLive live context and its single child component (Checkout). The architecture is minimal and focused — one LiveView handling the subscription checkout flow with a single dependency on MetricFlow.Billing.

## Architecture

- **Single responsibility**: Checkout handles plan display, Stripe Checkout session creation, and subscription management in one view. Appropriate given the narrow scope.
- **Dependency boundaries**: Only `MetricFlow.Billing` is listed, matching the Checkout spec's dependency. No cross-context coupling.
- **Dual billing path**: Checkout supports both platform-direct and agency-routed payments, delegated to the Billing context which handles Stripe account selection.

## Integration

- **Checkout -> Billing**: Creates checkout sessions via `Billing.create_checkout_session/3` and cancels subscriptions via `Billing.cancel_subscription/2`.
- **Stripe redirect flow**: Checkout initiates an external redirect to Stripe-hosted checkout and handles return URLs. No server-side payment handling in the LiveView.

## Conclusion

The SubscriptionLive context is ready for implementation. Specs are consistent and the single-view architecture is appropriate for the checkout use case.
