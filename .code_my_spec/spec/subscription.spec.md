# MetricFlow.Billing.Subscription

Ecto schema representing an active or past subscription. Stores account ID, plan ID, Stripe subscription and customer IDs, status, billing period dates, and cancellation timestamp.

## Type

module

## Dependencies

- MetricFlow.Accounts.Account
- MetricFlow.Billing.Plan

## Delegates

None

## Functions

### changeset/2

Build a changeset for creating or updating a subscription.

```elixir
@spec changeset(Subscription.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast required and optional fields
2. Validate required fields (stripe_subscription_id, stripe_customer_id, status, account_id)
3. Unique constraints on stripe_subscription_id and account_id
4. Foreign key constraints on account_id and plan_id

**Test Assertions**:
- returns valid changeset for valid attributes
- returns error changeset for missing required fields

## Fields

| Field | Type | Required | Description | Constraints |
| --- | --- | --- | --- | --- |
| id | integer | Yes (auto) | Primary key | Auto-generated |
| stripe_subscription_id | string | Yes | Stripe subscription ID | Unique |
| stripe_customer_id | string | Yes | Stripe customer ID | |
| status | enum | Yes | Subscription status | Default: :active |
| current_period_start | utc_datetime | No | Current billing period start | |
| current_period_end | utc_datetime | No | Current billing period end | |
| cancelled_at | utc_datetime | No | Cancellation timestamp | |
| account_id | integer | Yes | Subscribing account | References accounts.id, Unique |
| plan_id | integer | No | Associated plan | References billing_plans.id |
