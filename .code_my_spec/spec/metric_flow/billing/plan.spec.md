# MetricFlow.Billing.Plan

Ecto schema representing a subscription plan. Stores name, description, price_cents, currency, billing_interval (monthly/yearly), stripe_price_id, and the owning agency_account_id (nil for platform-level plans). Agencies create custom plans; the platform seeds a default flat-rate plan.

## Type

schema

## Dependencies

- MetricFlow.Accounts.Account
