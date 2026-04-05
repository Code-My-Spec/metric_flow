defmodule MetricFlow.Billing.StripeAccount do
  @moduledoc """
  Ecto schema representing a Stripe Connect account linked to an agency.

  Stores the agency account ID, Stripe account ID, onboarding status,
  and capabilities metadata.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Accounts.Account

  @type t :: %__MODULE__{}

  @onboarding_statuses [:pending, :complete, :restricted]

  schema "billing_stripe_accounts" do
    field :stripe_account_id, :string
    field :onboarding_status, Ecto.Enum, values: @onboarding_statuses, default: :pending
    field :capabilities, :map, default: %{}

    belongs_to :agency_account, Account

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(stripe_account_id agency_account_id)a
  @optional_fields ~w(onboarding_status capabilities)a

  def changeset(stripe_account, attrs) do
    stripe_account
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:agency_account_id])
    |> unique_constraint([:stripe_account_id])
  end
end
