# MetricFlowWeb.Hooks.RequireSubscriptionHook

LiveView on_mount hook that gates access to AI-powered features behind an active subscription. Free users are redirected to `/subscriptions/checkout` with a flash message. Users with active or trialing subscriptions pass through unrestricted.

## Type

module

## Dependencies

- MetricFlow.Billing.BillingRepository

## Delegates

None

## Functions

### on_mount/4

Check whether the current account has an active subscription. Halt and redirect free users to the checkout page.

```elixir
@spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract the current scope from socket assigns
2. Query BillingRepository for a subscription matching the account ID
3. If subscription status is :active or :trialing, continue with {:cont, socket}
4. Otherwise, put an error flash and redirect to /subscriptions/checkout with {:halt, socket}

**Test Assertions**:
- continues for accounts with active subscription
- continues for accounts with trialing subscription
- halts and redirects for accounts with no subscription
- halts and redirects for accounts with cancelled subscription
- halts and redirects for accounts with past_due subscription
- continues when no current scope is present
