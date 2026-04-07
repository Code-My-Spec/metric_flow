# Design Review

## Overview

Reviewed the MetricFlow.Billing context and its 6 child components (BillingRepository, Plan, Subscription, StripeAccount, StripeClient, WebhookProcessor). The architecture is sound — clean separation between data access (BillingRepository), external API integration (StripeClient), event processing (WebhookProcessor), and domain schemas (Plan, Subscription, StripeAccount).

## Architecture

- **Separation of concerns**: StripeClient handles all Stripe HTTP calls, BillingRepository handles all database queries, WebhookProcessor handles event dispatch. No overlapping responsibilities.
- **Schema design**: Three focused schemas (Plan, Subscription, StripeAccount) each represent a single Stripe concept with appropriate fields and constraints. Unique indexes on Stripe IDs enable webhook lookups.
- **Dependency direction**: WebhookProcessor depends on BillingRepository (not StripeClient), confirming it only processes already-verified events. The context module orchestrates StripeClient and BillingRepository together.
- **No circular dependencies**: Context -> StripeClient/BillingRepository -> Schemas. WebhookProcessor -> BillingRepository -> Schemas. Clean DAG.
- **Context as facade**: The Billing context delegates no functions but provides higher-level orchestration (create_checkout_session, cancel_subscription, create_connect_account) that compose child module calls.

## Integration

- **Context -> StripeClient**: Checkout session creation, subscription cancellation, and Connect account creation all flow through StripeClient for Stripe API calls.
- **Context -> BillingRepository**: All database persistence flows through BillingRepository — subscription lookups, plan queries, Stripe account management.
- **Context -> WebhookProcessor**: The context's process_webhook_event/1 dispatches to WebhookProcessor which uses BillingRepository to persist state changes.
- **External dependency**: Only MetricFlow.Accounts is listed as a context-level dependency, used for account lookups when scoping billing operations.
- **Test injection**: StripeClient accepts `:plug` option for Req test adapter, enabling cassette-based testing without mocks.

## Issues

- **StripeClient spec arity mismatch (fixed)**: `create_express_account` was listed as `/0` but implementation takes opts keyword argument (`/1`). Similarly `create_account_link` was `/1` but implementation is `/2`. Updated both to match implementation arities.

## Conclusion

The Billing context is ready for implementation. All specs are internally consistent, dependencies are validated, and the single issue (StripeClient arity mismatches) has been fixed.
