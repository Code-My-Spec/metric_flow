defmodule MetricFlow.Billing.ProcessedStripeEvent do
  @moduledoc """
  Ecto schema recording each Stripe webhook event ID that has been processed,
  so redelivered events can be recognized and treated as a no-op.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "processed_stripe_events" do
    field :stripe_event_id, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(processed_event, attrs) do
    processed_event
    |> cast(attrs, [:stripe_event_id])
    |> validate_required([:stripe_event_id])
    |> unique_constraint([:stripe_event_id])
  end
end
