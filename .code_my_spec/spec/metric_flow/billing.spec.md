# MetricFlow.Billing

Subscription billing and payment processing via Stripe. Manages direct user subscriptions (flat monthly plan charged to the platform's Stripe account), agency Stripe Connect onboarding, agency-defined subscription plans, and customer billing routed through agency-connected Stripe accounts. Processes Stripe webhooks for subscription lifecycle events (created, updated, cancelled, payment failed). Provides feature-gating queries to determine whether a user/account has an active paid subscription.

## Type

context

## Dependencies

- MetricFlow.Accounts

## Delegates

None

## Functions

### process_webhook_event/1

Process a verified Stripe webhook event. Dispatches to the appropriate handler based on event type.

```elixir
@spec process_webhook_event(map()) :: :ok | {:ok, :ignored} | {:error, term()}
```

**Process**:
1. Pattern match on the event type string
2. For subscription events, upsert subscription state via BillingRepository
3. For payment_failed, update subscription status to past_due
4. For account.updated, upsert Stripe Connect account status
5. For unrecognized types, return {:ok, :ignored}

**Test Assertions**:
- processes subscription.created and persists subscription
- processes subscription.updated and updates status
- processes subscription.deleted and marks as cancelled
- processes invoice.payment_failed and marks subscription as past_due
- processes invoice.payment_succeeded successfully
- processes account.updated for Connect onboarding
- returns ignored for unrecognized event types
- returns error for invalid event structure

### create_checkout_session/3

Create a Stripe Checkout session and return the checkout URL.

```elixir
@spec create_checkout_session(integer(), map(), String.t()) :: {:ok, String.t()} | {:error, term()}
```

**Process**:
1. Determine if plan belongs to an agency (check agency_account_id)
2. If agency plan, look up the agency's Stripe Connect account ID
3. Call StripeClient.create_checkout_session with plan and return URL
4. Return the checkout session URL

**Test Assertions**:
- creates checkout session for platform plan
- creates checkout session routed through agency Stripe account
- returns error when Stripe API fails

### cancel_subscription/1

Cancel a subscription at period end via the Stripe API.

```elixir
@spec cancel_subscription(integer()) :: :ok | {:error, term()}
```

**Process**:
1. Look up subscription by account ID
2. Call StripeClient.cancel_subscription with the Stripe subscription ID
3. Update local subscription status to cancelled with cancelled_at timestamp

**Test Assertions**:
- cancels active subscription and updates local status
- returns error when no subscription exists
- returns error when Stripe API fails

### create_connect_account/1

Create a Stripe Connect Express account and return the onboarding URL.

```elixir
@spec create_connect_account(integer()) :: {:ok, String.t()} | {:error, term()}
```

**Process**:
1. Create Express account via StripeClient
2. Persist the Stripe account ID in BillingRepository
3. Generate an account onboarding link
4. Return the onboarding URL

**Test Assertions**:
- creates Express account and returns onboarding URL
- returns error when Stripe API fails

### disconnect_stripe_account/1

Disconnect an agency's Stripe account.

```elixir
@spec disconnect_stripe_account(integer()) :: :ok | {:error, term()}
```

**Process**:
1. Look up Stripe account by agency account ID
2. Delete the local Stripe account record
3. Return :ok

**Test Assertions**:
- deletes Stripe account record
- returns error when not connected

## Components

### BillingRepository

Data access layer for Subscription, Plan, and StripeAccount CRUD operations. Provides subscription lookups by account and Stripe ID, plan management for agencies, and Stripe Connect account queries.

### Plan

Ecto schema representing a subscription plan with name, price, currency, billing interval, Stripe Price ID, and agency ownership.

### Subscription

Ecto schema representing an active or past subscription with Stripe IDs, status, billing period dates, and account association.

### StripeAccount

Ecto schema representing a Stripe Connect account linked to an agency with onboarding status and capabilities.

### StripeClient

Stripe API integration layer using Req. Handles webhook signature verification, checkout session creation, Connect account management, and product/price CRUD.

### WebhookProcessor

Processes verified Stripe webhook events for subscription lifecycle sync.
