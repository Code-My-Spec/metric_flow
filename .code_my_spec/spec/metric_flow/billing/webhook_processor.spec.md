# MetricFlow.Billing.WebhookProcessor

Processes verified Stripe webhook events. Handles subscription.created, subscription.updated, subscription.deleted, invoice.payment_failed, and account.updated (for Connect onboarding status). Updates local subscription and Stripe account records to match Stripe state.

## Type

module

## Dependencies

- MetricFlow.Billing.BillingRepository
