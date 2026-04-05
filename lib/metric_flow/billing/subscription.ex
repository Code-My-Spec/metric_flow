defmodule MetricFlow.Billing.Subscription do
  @moduledoc """
  Ecto schema representing an active or past subscription.

  Stores account ID, plan ID, Stripe subscription and customer IDs,
  status, billing period dates, and cancellation timestamp.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Billing.Plan

  @type t :: %__MODULE__{}

  @statuses [:active, :past_due, :cancelled, :trialing, :incomplete]

  schema "billing_subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :account, Account
    belongs_to :plan, Plan

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(stripe_subscription_id stripe_customer_id status account_id)a
  @optional_fields ~w(plan_id current_period_start current_period_end cancelled_at)a

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:stripe_subscription_id])
    |> unique_constraint([:account_id])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:plan_id)
  end
end
