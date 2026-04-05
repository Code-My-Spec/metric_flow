# MetricFlow.Billing.StripeAccount

Ecto schema representing a Stripe Connect account linked to an agency. Stores the agency account ID, Stripe account ID, onboarding status, and capabilities metadata.

## Type

module

## Dependencies

- MetricFlow.Accounts.Account

## Delegates

None

## Functions

### changeset/2

Build a changeset for creating or updating a Stripe Connect account record.

```elixir
@spec changeset(StripeAccount.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast required and optional fields
2. Validate required fields (stripe_account_id, agency_account_id)
3. Unique constraints on agency_account_id and stripe_account_id

**Test Assertions**:
- returns valid changeset for valid attributes
- returns error changeset for missing required fields

## Fields

| Field | Type | Required | Description | Constraints |
| --- | --- | --- | --- | --- |
| id | integer | Yes (auto) | Primary key | Auto-generated |
| stripe_account_id | string | Yes | Stripe Connect account ID | Unique |
| onboarding_status | enum | Yes | Onboarding state | Default: :pending |
| capabilities | map | No | Stripe capabilities | Default: %{} |
| agency_account_id | integer | Yes | Owning agency | References accounts.id, Unique |
