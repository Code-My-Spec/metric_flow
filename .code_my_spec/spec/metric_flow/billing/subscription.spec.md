# MetricFlow.Billing.Subscription

Ecto schema representing an active or past subscription. Stores account_id, plan_id, stripe_subscription_id, stripe_customer_id, status (active, past_due, cancelled, trialing), current_period_start, current_period_end, and cancelled_at. Belongs to Account and Plan. Indexed on [account_id] and [stripe_subscription_id] for webhook lookups.

## Type

schema

## Dependencies

- MetricFlow.Billing.Plan
- MetricFlow.Accounts.Account
