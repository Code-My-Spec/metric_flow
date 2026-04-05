# MetricFlow.Billing.StripeAccount

Ecto schema representing a Stripe Connect account linked to an agency. Stores agency_account_id, stripe_account_id, onboarding_status (pending, complete, restricted), and capabilities metadata. One record per agency account, enforced by unique constraint.

## Type

schema

## Dependencies

- MetricFlow.Accounts.Account
