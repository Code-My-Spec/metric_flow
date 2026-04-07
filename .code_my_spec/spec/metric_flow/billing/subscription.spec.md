# MetricFlow.Billing.Subscription

Ecto schema representing an active or past subscription. Stores account_id, plan_id, stripe_subscription_id, stripe_customer_id, status (active, past_due, cancelled, trialing), current_period_start, current_period_end, and cancelled_at. Belongs to Account and Plan. Indexed on [account_id] and [stripe_subscription_id] for webhook lookups.

## Type

schema

## Fields

| Field | Type | Required | Description | Constraints |
| ----- | ---- | -------- | ----------- | ----------- |
| id | integer | Yes (auto) | Primary key | Auto-generated |
| stripe_subscription_id | string | Yes | Stripe subscription identifier | Unique |
| stripe_customer_id | string | Yes | Stripe customer identifier | |
| status | enum | Yes | Subscription lifecycle state | Values: active, past_due, cancelled, trialing, incomplete. Default: active |
| current_period_start | utc_datetime | No | Start of current billing period | |
| current_period_end | utc_datetime | No | End of current billing period | |
| cancelled_at | utc_datetime | No | When the subscription was cancelled | |
| account_id | integer | Yes | Foreign key to account | References accounts.id, unique |
| plan_id | integer | No | Foreign key to billing plan | References billing_plans.id |
| inserted_at | utc_datetime | Yes (auto) | Record creation timestamp | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Record update timestamp | Auto-generated |

## Functions

### changeset/2

Casts and validates subscription attributes.

```elixir
@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast required fields (stripe_subscription_id, stripe_customer_id, status, account_id) and optional fields (plan_id, current_period_start, current_period_end, cancelled_at)
2. Validate required fields are present
3. Apply unique constraints on stripe_subscription_id and account_id
4. Apply foreign key constraints on account_id and plan_id

## Dependencies

- MetricFlow.Billing.Plan
- MetricFlow.Accounts.Account
