# ADR 26: Stripe Billing

## Status

Accepted

## Context

MetricFlow needs subscription billing to gate AI features (Correlations, Intelligence, Visualizations) behind a paid plan. The platform serves two billing models:

1. **Direct users** subscribe to a flat monthly plan — payments flow to the platform's own Stripe account.
2. **Agency customers** subscribe to agency-defined plans — payments flow to the agency's connected Stripe account via Stripe Connect.

We need a billing provider that supports both models, webhook-driven lifecycle sync, and Stripe Connect for multi-party payments.

## Decision

Use **Stripe** with the following architecture:

### Stripe Products

- **Stripe Checkout Sessions** for payment collection — redirect to Stripe-hosted checkout, no PCI scope.
- **Stripe Connect Express** for agency onboarding — agencies connect via Stripe-hosted onboarding flow, platform takes no payment responsibility.
- **Stripe Webhooks** for lifecycle sync — subscription state is kept in sync via `customer.subscription.*` and `invoice.*` events.

### Local Architecture

- **`MetricFlow.Billing`** context owns all billing logic.
- **`Billing.StripeClient`** wraps Stripe API calls via `Req`. Accepts `:http_plug` for test injection.
- **`Billing.Subscription`**, **`Billing.Plan`**, **`Billing.StripeAccount`** schemas persist local state.
- **`BillingWebhookController`** receives webhook events on `POST /billing/webhooks` under the `:api` pipeline (no CSRF, no session).
- Webhook signature verification uses HMAC-SHA256 per Stripe's `v1` scheme.

### Local Development

- **Permanent webhook endpoint** registered in Stripe test mode pointing at `https://dev.metric-flow.app/billing/webhooks` (Cloudflare tunnel → localhost:4070).
- Endpoint ID: `we_1TIvE8GkgiYxMEomtkIaDURR` — stable `whsec_` secret stored in `.env.dev`.
- Events are delivered automatically whenever the dev server is running — no CLI listener process needed.
- `stripe trigger` CLI command can be used to fire test events on demand.
- Test-mode keys (`sk_test_`, `pk_test_`) in `.env.dev` for development.

### Testing

- Webhook controller tests generate real HMAC signatures against a test secret — no Stripe API calls needed.
- `StripeClient` API calls (product/price creation) are boundary-layer — use ReqCassette or test plugs for recording.
- BDD specs test through the UI and are expected to fail until routes and LiveViews are fully implemented (red-green-refactor).

## Alternatives Considered

- **Paddle** — simpler merchant-of-record model but no Connect equivalent for agency billing.
- **LemonSqueezy** — same limitation, no multi-party payment support.
- **Roll-your-own with bank transfers** — too much payment infrastructure to build and maintain.

## Consequences

- Stripe is a hard dependency for billing features.
- Platform must maintain PCI compliance for Checkout Sessions (minimal — Stripe-hosted).
- Agency Stripe Connect adds complexity but enables the two-sided billing model.
- Webhook idempotency must be handled (duplicate event IDs).
- Subscription state can drift if webhooks are missed — need monitoring/reconciliation.
