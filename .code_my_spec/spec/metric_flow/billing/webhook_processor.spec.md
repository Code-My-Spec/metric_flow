# MetricFlow.Billing.WebhookProcessor

Processes verified Stripe webhook events. Handles subscription.created, subscription.updated, subscription.deleted, invoice.payment_failed, and account.updated (for Connect onboarding status). Updates local subscription and Stripe account records to match Stripe state.

## Type

module

## Delegates

None

## Functions

### process_event/1

Dispatches a verified Stripe webhook event to the appropriate handler based on event type.

```elixir
@spec process_event(Stripe.Event.t()) :: :ok | {:error, term()}
```

**Process**:
1. Pattern match on event type string
2. For `customer.subscription.created` — upsert a local Subscription record from the Stripe subscription object via BillingRepository
3. For `customer.subscription.updated` — update the local Subscription record's status, period dates, and cancelled_at from the Stripe subscription object
4. For `customer.subscription.deleted` — mark the local Subscription as cancelled and set cancelled_at
5. For `invoice.payment_failed` — update the associated Subscription status to past_due
6. For `account.updated` — update the local StripeAccount record's onboarding status (charges_enabled, payouts_enabled, details_submitted)
7. For unrecognized event types — log and return :ok (no-op)

**Test Assertions**:
- creates a local subscription from a subscription.created event
- updates subscription status and period from a subscription.updated event
- marks subscription as cancelled from a subscription.deleted event
- sets subscription to past_due from an invoice.payment_failed event
- updates Stripe account onboarding status from an account.updated event
- returns :ok for unrecognized event types

## Dependencies

- MetricFlow.Billing.BillingRepository
