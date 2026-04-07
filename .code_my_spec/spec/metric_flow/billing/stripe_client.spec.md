# MetricFlow.Billing.StripeClient

Stripe API integration layer using Req. Handles checkout session creation, subscription management, Connect account creation/onboarding, and webhook signature verification. Wraps Stripe API calls with error handling and token management. Accepts an `:http_plug` option for dependency injection during tests.

## Type

module

## Delegates

None

## Functions

### verify_webhook_signature/3

Verify a Stripe webhook signature against the raw request body.

```elixir
@spec verify_webhook_signature(binary(), binary(), binary()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Parse the signature header to extract timestamp and v1 signatures
2. Compute the expected HMAC-SHA256 signature from the timestamp, body, and secret
3. Securely compare each v1 signature against the expected value
4. On match, decode the JSON body and return `{:ok, event}`

**Test Assertions**:
- returns {:ok, event} for valid signature and body
- returns {:error, :signature_mismatch} for invalid signature
- returns {:error, :missing_signature} for nil or empty signature
- returns {:error, :invalid_signature_format} for malformed signature header
- returns {:error, :invalid_json} for valid signature but invalid JSON body

### create_product/2

Create a Stripe Product for an agency plan.

```elixir
@spec create_product(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Extract optional `:stripe_account` from opts for Connect header
2. POST to Stripe `/v1/products` with name and type "service"
3. Return `{:ok, product_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, product} on successful creation
- returns {:error, message} on Stripe API error
- passes Stripe-Account header when stripe_account opt is provided

### create_price/3

Create a Stripe Price for a product.

```elixir
@spec create_price(String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Extract currency (default "usd"), interval (default "month"), and stripe_account from opts
2. POST to Stripe `/v1/prices` with product, unit_amount, currency, and recurring interval
3. Return `{:ok, price_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, price} on successful creation
- defaults currency to "usd" and interval to "month"
- returns {:error, message} on Stripe API error

### deactivate_price/2

Deactivate a Stripe Price by setting active to false.

```elixir
@spec deactivate_price(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe `/v1/prices/:id` with active=false
2. Return `{:ok, price_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, price} with active false on success
- returns {:error, message} on Stripe API error

### create_checkout_session/3

Create a Stripe Checkout session for a subscription plan.

```elixir
@spec create_checkout_session(map(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Build checkout params with mode "subscription", the plan's stripe_price_id, and success/cancel URLs
2. POST to Stripe `/v1/checkout/sessions`
3. Return `{:ok, session_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, session} with checkout URL on success
- returns {:error, message} on Stripe API error

### cancel_subscription/2

Cancel a Stripe subscription at period end.

```elixir
@spec cancel_subscription(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe `/v1/subscriptions/:id` with cancel_at_period_end=true
2. Return `{:ok, subscription_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, subscription} with cancel_at_period_end true on success
- returns {:error, message} on Stripe API error

### create_express_account/1

Create a Stripe Connect Express account for agency onboarding.

```elixir
@spec create_express_account(keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. POST to Stripe `/v1/accounts` with type "express"
2. Return `{:ok, account_map}` on 2xx, `{:error, reason}` otherwise

**Test Assertions**:
- returns {:ok, account} with Stripe account ID on success
- returns {:error, message} on Stripe API error

### create_account_link/2

Create an account link for Stripe Connect onboarding redirect.

```elixir
@spec create_account_link(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Build return/refresh URLs pointing to `/agency/stripe-connect`
2. POST to Stripe `/v1/account_links` with account ID and onboarding type
3. Return `{:ok, link_map}` containing the onboarding URL

**Test Assertions**:
- returns {:ok, link} with URL on success
- returns {:error, message} on Stripe API error

## Dependencies

None
