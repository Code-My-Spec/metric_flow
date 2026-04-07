# MetricFlow.Billing.BillingRepository

Data access layer for Subscription, Plan, and StripeAccount CRUD operations. All queries are scoped via Scope struct for multi-tenant isolation. Provides subscription lookups by account, plan management for agencies, and Stripe Connect account queries.

## Type

module

## Delegates

None

## Functions

### get_subscription_by_stripe_id/1

Looks up a subscription by its Stripe subscription ID.

```elixir
@spec get_subscription_by_stripe_id(String.t()) :: Subscription.t() | nil
```

**Process**:
1. Query billing_subscriptions where stripe_subscription_id matches

**Test Assertions**:
- returns the subscription when stripe_subscription_id matches
- returns nil when no subscription matches

### get_subscription_by_account_id/1

Looks up a subscription by its account ID.

```elixir
@spec get_subscription_by_account_id(integer()) :: Subscription.t() | nil
```

**Process**:
1. Query billing_subscriptions where account_id matches

**Test Assertions**:
- returns the subscription when account_id matches
- returns nil when no subscription matches

### upsert_subscription/1

Creates or updates a subscription based on stripe_subscription_id.

```elixir
@spec upsert_subscription(map()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Look up existing subscription by stripe_subscription_id from attrs
2. If not found, insert a new Subscription record
3. If found, update the existing record with new attrs

**Test Assertions**:
- creates a new subscription when stripe_subscription_id does not exist
- updates an existing subscription when stripe_subscription_id already exists
- returns error changeset when required fields are missing

### list_plans/1

Lists active plans, optionally filtered by agency account ID.

```elixir
@spec list_plans(integer() | nil) :: [Plan.t()]
```

**Process**:
1. Query billing_plans where active is true
2. If agency_account_id is nil, filter to plans with no agency
3. If agency_account_id is provided, filter to that agency's plans
4. Order by price_cents ascending

**Test Assertions**:
- returns platform plans when agency_account_id is nil
- returns agency-specific plans when agency_account_id is provided
- excludes inactive plans
- returns plans ordered by price ascending

### get_plan/1

Fetches a single plan by ID.

```elixir
@spec get_plan(integer()) :: Plan.t() | nil
```

**Process**:
1. Query billing_plans by primary key

**Test Assertions**:
- returns the plan when ID matches
- returns nil when no plan matches

### create_plan/1

Creates a new billing plan.

```elixir
@spec create_plan(map()) :: {:ok, Plan.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build a Plan changeset from attrs
2. Insert into the database

**Test Assertions**:
- creates a plan with valid attributes
- returns error changeset when required fields are missing

### get_stripe_account_by_agency/1

Looks up a Stripe Connect account by agency account ID.

```elixir
@spec get_stripe_account_by_agency(integer()) :: StripeAccount.t() | nil
```

**Process**:
1. Query billing_stripe_accounts where agency_account_id matches

**Test Assertions**:
- returns the stripe account when agency_account_id matches
- returns nil when no stripe account matches

### upsert_stripe_account/1

Creates or updates a Stripe Connect account based on agency_account_id.

```elixir
@spec upsert_stripe_account(map()) :: {:ok, StripeAccount.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Look up existing StripeAccount by agency_account_id from attrs
2. If not found, insert a new StripeAccount record
3. If found, update the existing record with new attrs

**Test Assertions**:
- creates a new stripe account when agency_account_id does not exist
- updates an existing stripe account when agency_account_id already exists
- returns error changeset when required fields are missing

### list_agency_subscriptions/2

Lists subscriptions for plans owned by an agency, with optional search and pagination.

```elixir
@spec list_agency_subscriptions(integer(), keyword()) :: [Subscription.t()]
```

**Process**:
1. Join subscriptions with plans on plan_id
2. Filter where plan's agency_account_id matches
3. Optionally filter by search term on stripe_customer_id
4. Order by inserted_at descending
5. Apply limit and offset for pagination
6. Preload plan association

**Test Assertions**:
- returns subscriptions for plans owned by the agency
- returns empty list when agency has no subscriptions
- filters by search term when provided

### count_active_agency_subscriptions/1

Counts active subscriptions for an agency's plans.

```elixir
@spec count_active_agency_subscriptions(integer()) :: non_neg_integer()
```

**Process**:
1. Join subscriptions with plans on plan_id
2. Filter where plan's agency_account_id matches and status is active
3. Return count

**Test Assertions**:
- returns count of active subscriptions for the agency
- returns 0 when no active subscriptions exist

### calculate_mrr/1

Calculates monthly recurring revenue for an agency from active subscriptions.

```elixir
@spec calculate_mrr(integer()) :: non_neg_integer()
```

**Process**:
1. Join subscriptions with plans on plan_id
2. Filter where plan's agency_account_id matches and status is active
3. Sum plan price_cents, defaulting to 0

**Test Assertions**:
- returns sum of price_cents from active subscriptions
- returns 0 when no active subscriptions exist

## Dependencies

- MetricFlow.Billing.StripeAccount
- MetricFlow.Billing.Plan
- MetricFlow.Billing.Subscription
