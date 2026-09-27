defmodule MetricFlow.Billing.ProcessedStripeEvent do
  @moduledoc """
  Ecto schema recording each Stripe webhook event that has been received,
  so redelivered events can be recognized and treated as a no-op, and so
  every event's type and outcome are durably auditable.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses [:processing, :processed, :failed]

  schema "processed_stripe_events" do
    field :stripe_event_id, :string
    field :event_type, :string
    field :status, Ecto.Enum, values: @statuses, default: :processing

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(processed_event, attrs) do
    processed_event
    |> cast(attrs, [:stripe_event_id, :event_type, :status])
    |> validate_required([:stripe_event_id])
    |> unique_constraint([:stripe_event_id])
  end

  @doc """
  Records the outcome of processing, once dispatch has run.
  """
  def status_changeset(processed_event, status) when status in @statuses do
    cast(processed_event, %{status: status}, [:status])
  end
end
