# MetricFlow.Billing.StripeClient

Stripe API integration layer using Req. Handles webhook signature verification, checkout session creation, Connect account management, and product/price CRUD. Accepts `:http_plug` option for dependency injection during tests.

## Type

module

## Dependencies

None

## Delegates

None

## Functions

### verify_webhook_signature/3

Verify a Stripe webhook signature against the raw request body.

```elixir
@spec verify_webhook_signature(binary(), binary(), binary()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Parse the Stripe-Signature header for timestamp and v1 signatures
2. Compute expected HMAC-SHA256 signature
3. Compare against provided signatures using secure_compare
4. Parse and return the event JSON on success

**Test Assertions**:
- returns event for valid signature
- returns error for missing signature
- returns error for mismatched signature
- returns error for invalid JSON body

### create_checkout_session/3

Create a Stripe Checkout session for a plan.

```elixir
@spec create_checkout_session(map(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Build checkout session params with line items and return URLs
2. POST to Stripe API with optional connected account header

**Test Assertions**:
- creates session and returns URL

### create_express_account/0

Create a Stripe Connect Express account.

```elixir
@spec create_express_account() :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe accounts API with type=express

**Test Assertions**:
- creates account and returns account map

### create_account_link/1

Create an account link for Stripe Connect onboarding.

```elixir
@spec create_account_link(String.t()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe account_links API with return and refresh URLs

**Test Assertions**:
- creates link and returns URL

### create_product/2

Create a Stripe Product for an agency plan.

```elixir
@spec create_product(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe products API with name and optional connected account

**Test Assertions**:
- creates product and returns product map

### create_price/3

Create a Stripe Price for a product.

```elixir
@spec create_price(String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe prices API with product, amount, currency, interval

**Test Assertions**:
- creates price and returns price map

### deactivate_price/2

Deactivate a Stripe Price by setting active to false.

```elixir
@spec deactivate_price(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe prices API with active=false

**Test Assertions**:
- deactivates price successfully

### cancel_subscription/2

Cancel a Stripe subscription at period end.

```elixir
@spec cancel_subscription(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe subscriptions API with cancel_at_period_end=true

**Test Assertions**:
- cancels subscription at period end
