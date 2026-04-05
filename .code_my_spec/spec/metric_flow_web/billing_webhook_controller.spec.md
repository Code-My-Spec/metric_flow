# MetricFlowWeb.BillingWebhookController

Stripe webhook endpoint handler. Receives and verifies Stripe webhook events using signature verification, then delegates to Billing.WebhookProcessor for subscription lifecycle sync. Handles subscription.created, subscription.updated, subscription.deleted, invoice.payment_failed, and account.updated events. Returns 200 for processed events and 400 for verification failures. Does not require user authentication — secured by Stripe webhook signing secret.

## Type

controller

## Dependencies

- MetricFlow.Billing
- MetricFlow.Billing.StripeClient

## Delegates

None

## Functions

### handle/2

Receives a Stripe webhook event, verifies the signature, and delegates processing to the Billing context.

```elixir
@spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
```

**Process**:
1. Read the raw request body from the connection
2. Extract the `stripe-signature` header
3. Call `StripeClient.verify_webhook_signature/3` with the raw body, signature, and webhook secret
4. If verification fails, return 400 with error message
5. Parse the verified event JSON
6. Delegate to `Billing.process_webhook_event/1` with the parsed event
7. Return 200 on success
8. Return 400 for malformed payloads or missing signature
9. For unrecognized event types, return 200 (acknowledge without processing)

**Test Assertions**:
- returns 200 for valid subscription.created event
- returns 200 for valid subscription.updated event
- returns 200 for valid subscription.deleted event
- returns 200 for valid invoice.payment_failed event
- returns 200 for valid invoice.payment_succeeded event
- returns 200 for valid account.updated event (Connect onboarding)
- returns 200 for unrecognized event types without crashing
- returns 400 when Stripe-Signature header is missing
- returns 400 when signature verification fails
- returns 400 for malformed JSON payload
- handles duplicate event delivery idempotently (same event ID processed twice returns 200 both times)
