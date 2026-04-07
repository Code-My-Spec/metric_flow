# MetricFlow.Billing.StripeAccount

Ecto schema representing a Stripe Connect account linked to an agency. Stores agency_account_id, stripe_account_id, onboarding_status (pending, complete, restricted), and capabilities metadata. One record per agency account, enforced by unique constraint.

## Type

schema

## Fields

| Field              | Type         | Required   | Description                                         | Constraints                        |
| ------------------ | ------------ | ---------- | --------------------------------------------------- | ---------------------------------- |
| id                 | integer      | Yes (auto) | Primary key                                         | Auto-generated                     |
| stripe_account_id  | string       | Yes        | Stripe Connect account identifier (acct_...)        | Unique constraint                  |
| onboarding_status  | enum         | No         | Connect onboarding state                            | Default: :pending, values: pending/complete/restricted |
| capabilities       | map          | No         | Stripe account capabilities metadata                | Default: %{}                       |
| agency_account_id  | integer      | Yes        | Owning agency account                               | References accounts.id, unique     |
| inserted_at        | utc_datetime | Yes (auto) | Creation timestamp                                  | Auto-generated                     |
| updated_at         | utc_datetime | Yes (auto) | Last update timestamp                               | Auto-generated                     |

Onboarding status transitions: pending -> complete (successful onboarding), pending -> restricted (incomplete or flagged by Stripe), restricted -> complete (issues resolved).

## Functions

### changeset/2

Builds a changeset for creating or updating a Stripe Connect account record.

```elixir
@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Casts required fields (stripe_account_id, agency_account_id) and optional fields (onboarding_status, capabilities)
2. Validates required fields are present
3. Applies unique constraint on agency_account_id (one Stripe account per agency)
4. Applies unique constraint on stripe_account_id

**Test Assertions**:
- valid changeset with required fields
- invalid changeset when stripe_account_id is missing
- invalid changeset when agency_account_id is missing
- enforces unique constraint on agency_account_id
- enforces unique constraint on stripe_account_id
- defaults onboarding_status to :pending

## Dependencies

- MetricFlow.Accounts.Account
