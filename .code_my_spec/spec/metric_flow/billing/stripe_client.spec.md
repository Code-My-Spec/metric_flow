# MetricFlow.Billing.StripeClient

Stripe API integration layer using Req. Handles checkout session creation, subscription management, Connect account creation/onboarding, and webhook signature verification. Wraps Stripe API calls with error handling and token management. Accepts an `:http_plug` option for dependency injection during tests.

## Type

module
