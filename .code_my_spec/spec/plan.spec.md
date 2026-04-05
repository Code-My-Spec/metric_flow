# MetricFlow.Billing.Plan

Ecto schema representing a subscription plan. Stores name, description, price in cents, currency, billing interval, Stripe Price ID, and the owning agency account ID (nil for platform-level plans).

## Type

module

## Dependencies

- MetricFlow.Accounts.Account

## Delegates

None

## Functions

### changeset/2

Build a changeset for creating or updating a plan.

```elixir
@spec changeset(Plan.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast required and optional fields
2. Validate required fields (name, price_cents, currency, billing_interval)
3. Validate name length, price_cents > 0, currency inclusion
4. Unique constraint on stripe_price_id

**Test Assertions**:
- returns valid changeset for valid attributes
- returns error changeset for missing required fields
- validates price_cents is greater than 0
- validates currency is one of usd, eur, gbp

## Fields

| Field | Type | Required | Description | Constraints |
| --- | --- | --- | --- | --- |
| id | integer | Yes (auto) | Primary key | Auto-generated |
| name | string | Yes | Plan name | Min: 1, Max: 255 |
| description | string | No | Plan description | |
| price_cents | integer | Yes | Price in cents | Greater than 0 |
| currency | string | Yes | ISO currency code | Default: "usd" |
| billing_interval | enum | Yes | Monthly or yearly | Default: :monthly |
| stripe_price_id | string | No | Stripe Price object ID | Unique |
| active | boolean | Yes | Whether plan is active | Default: true |
| agency_account_id | integer | No | Owning agency | References accounts.id |
