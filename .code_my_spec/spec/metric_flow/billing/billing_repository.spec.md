# MetricFlow.Billing.BillingRepository

Data access layer for Subscription, Plan, and StripeAccount CRUD operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides subscription lookups by account, plan management for agencies, and Stripe Connect account queries.

## Type

module

## Dependencies

- MetricFlow.Billing.StripeAccount
- MetricFlow.Billing.Plan
- MetricFlow.Billing.Subscription
