defmodule MetricFlow.Billing.Plan do
  @moduledoc """
  Ecto schema representing a subscription plan.

  Stores name, description, price in cents, currency, billing interval,
  Stripe Price ID, and the owning agency account ID (nil for platform plans).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{}

  schema "billing_plans" do
    field :name, :string
    field :description, :string
    field :price_cents, :integer
    field :currency, :string, default: "usd"
    field :billing_interval, Ecto.Enum, values: [:monthly, :yearly], default: :monthly
    field :stripe_price_id, :string
    field :active, :boolean, default: true

    belongs_to :agency_account, Account

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(name price_cents currency billing_interval)a
  @optional_fields ~w(description stripe_price_id active agency_account_id)a

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:price_cents, greater_than: 0)
    |> validate_inclusion(:currency, ["usd", "eur", "gbp"])
    |> unique_constraint([:stripe_price_id])
  end
end
