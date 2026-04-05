# MetricFlow.Billing.WebhookProcessor

Processes verified Stripe webhook events for subscription lifecycle sync. Delegates event handling to the Billing context based on event type.

## Type

module

## Dependencies

- MetricFlow.Billing

## Delegates

None

## Functions

### process/1

Process a verified webhook event by delegating to the appropriate Billing context handler.

```elixir
@spec process(map()) :: :ok | {:ok, :ignored} | {:error, term()}
```

**Process**:
1. Extract event type from the event map
2. Delegate to Billing.process_webhook_event/1

**Test Assertions**:
- processes subscription.created event
- processes invoice.payment_failed event
- returns ignored for unrecognized event types
