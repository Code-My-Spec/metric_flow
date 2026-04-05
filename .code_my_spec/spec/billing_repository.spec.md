# MetricFlow.Billing.BillingRepository

Data access layer for Subscription, Plan, and StripeAccount CRUD operations. All queries are scoped for multi-tenant isolation. Provides subscription lookups by account and Stripe ID, plan management for agencies, and Stripe Connect account queries.

## Type

module

## Dependencies

- MetricFlow.Billing.Subscription
- MetricFlow.Billing.Plan
- MetricFlow.Billing.StripeAccount

## Delegates

None

## Functions

### get_subscription_by_stripe_id/1

Look up a subscription by its Stripe subscription ID.

```elixir
@spec get_subscription_by_stripe_id(String.t()) :: Subscription.t() | nil
```

**Process**:
1. Query subscriptions table by stripe_subscription_id

**Test Assertions**:
- returns subscription when found
- returns nil when not found

### get_subscription_by_account_id/1

Look up a subscription by account ID.

```elixir
@spec get_subscription_by_account_id(integer()) :: Subscription.t() | nil
```

**Process**:
1. Query subscriptions table by account_id

**Test Assertions**:
- returns subscription when found
- returns nil when not found

### upsert_subscription/1

Insert or update a subscription based on stripe_subscription_id.

```elixir
@spec upsert_subscription(map()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Look up existing subscription by stripe_subscription_id
2. If found, update with new attributes
3. If not found, insert new subscription

**Test Assertions**:
- inserts new subscription when none exists
- updates existing subscription when found
- returns error for invalid attributes

### list_plans/1

List active plans, optionally filtered by agency account ID.

```elixir
@spec list_plans(integer() | nil) :: [Plan.t()]
```

**Process**:
1. Query active plans
2. Filter by agency_account_id (nil for platform plans)
3. Order by price ascending

**Test Assertions**:
- returns platform plans when agency_account_id is nil
- returns agency plans when agency_account_id is provided
- returns empty list when no plans exist

### get_plan/1

Get a plan by ID.

```elixir
@spec get_plan(integer()) :: Plan.t() | nil
```

**Process**:
1. Query plans table by ID

**Test Assertions**:
- returns plan when found
- returns nil when not found

### create_plan/1

Create a new plan.

```elixir
@spec create_plan(map()) :: {:ok, Plan.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build changeset from attributes
2. Insert into database

**Test Assertions**:
- creates plan with valid attributes
- returns error for invalid attributes

### get_stripe_account_by_agency/1

Look up a Stripe Connect account by agency account ID.

```elixir
@spec get_stripe_account_by_agency(integer()) :: StripeAccount.t() | nil
```

**Process**:
1. Query stripe accounts table by agency_account_id

**Test Assertions**:
- returns stripe account when found
- returns nil when not found

### upsert_stripe_account/1

Insert or update a Stripe Connect account based on agency_account_id.

```elixir
@spec upsert_stripe_account(map()) :: {:ok, StripeAccount.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Look up existing Stripe account by agency_account_id
2. If found, update with new attributes
3. If not found, insert new record

**Test Assertions**:
- inserts new stripe account when none exists
- updates existing stripe account when found

### list_agency_subscriptions/2

List subscriptions for plans owned by an agency.

```elixir
@spec list_agency_subscriptions(integer(), keyword()) :: [Subscription.t()]
```

**Process**:
1. Join subscriptions with plans on plan_id
2. Filter by plan's agency_account_id
3. Apply search and pagination

**Test Assertions**:
- returns subscriptions for agency plans
- returns empty list when no subscriptions exist

### count_active_agency_subscriptions/1

Count active subscriptions for an agency's plans.

```elixir
@spec count_active_agency_subscriptions(integer()) :: integer()
```

**Process**:
1. Join subscriptions with plans, filter by agency and active status, return count

**Test Assertions**:
- returns count of active subscriptions
- returns 0 when no active subscriptions

### calculate_mrr/1

Calculate monthly recurring revenue for an agency.

```elixir
@spec calculate_mrr(integer()) :: integer()
```

**Process**:
1. Sum plan prices for active subscriptions under the agency

**Test Assertions**:
- returns sum of active plan prices
- returns 0 when no active subscriptions
