# MetricFlow.Billing.Plan

Ecto schema representing a subscription plan. Stores name, description, price_cents, currency, billing_interval (monthly/yearly), stripe_price_id, and the owning agency_account_id (nil for platform-level plans). Agencies create custom plans; the platform seeds a default flat-rate plan.

## Type

schema

## Fields

| Field              | Type         | Required   | Description                                          | Constraints                              |
| ------------------ | ------------ | ---------- | ---------------------------------------------------- | ---------------------------------------- |
| id                 | integer      | Yes (auto) | Primary key                                          | Auto-generated                           |
| name               | string       | Yes        | Plan display name                                    | Min: 1, Max: 255                         |
| description        | string       | No         | Human-readable plan description                      |                                          |
| price_cents        | integer      | Yes        | Price in cents                                       | Greater than 0                           |
| currency           | string       | Yes        | ISO currency code                                    | Default: "usd", one of: usd, eur, gbp   |
| billing_interval   | enum         | Yes        | Billing cycle                                        | Default: :monthly, values: monthly/yearly|
| stripe_price_id    | string       | No         | Stripe Price object ID                               | Unique constraint                        |
| active             | boolean      | No         | Whether the plan is available for new subscriptions  | Default: true                            |
| agency_account_id  | integer      | No         | Owning agency account (nil for platform-level plans) | References accounts.id                   |
| inserted_at        | utc_datetime | Yes (auto) | Creation timestamp                                   | Auto-generated                           |
| updated_at         | utc_datetime | Yes (auto) | Last update timestamp                                | Auto-generated                           |

## Functions

### changeset/2

Builds a changeset for creating or updating a plan.

```elixir
@spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Casts required fields (name, price_cents, currency, billing_interval) and optional fields (description, stripe_price_id, active, agency_account_id)
2. Validates required fields are present
3. Validates name length (1-255 characters)
4. Validates price_cents is greater than 0
5. Validates currency is one of "usd", "eur", "gbp"
6. Applies unique constraint on stripe_price_id

**Test Assertions**:
- valid changeset with all required fields
- invalid changeset when name is missing
- invalid changeset when price_cents is zero or negative
- invalid changeset when currency is not in allowed list
- enforces unique constraint on stripe_price_id

## Dependencies

- MetricFlow.Accounts.Account
