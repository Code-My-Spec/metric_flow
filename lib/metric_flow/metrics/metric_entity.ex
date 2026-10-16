defmodule MetricFlow.Metrics.MetricEntity do
  @moduledoc "An account-owned provider entity with a stable external identity."
  use Ecto.Schema
  import Ecto.Changeset

  schema "metric_entities" do
    field :account_id, :integer
    field :provider, :string
    field :entity_type, :string
    field :external_id, :string
    field :parent_entity_id, :integer
    field :display_name, :string
    field :published_at, :utc_datetime_usec
    field :metadata, :map, default: %{}
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:display_name, :published_at, :metadata])
    |> validate_required([:account_id, :provider, :entity_type, :external_id, :display_name])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:parent_entity_id, name: :metric_entities_parent_scope)
    |> unique_constraint([:account_id, :provider, :entity_type, :external_id],
      name: :metric_entities_identity
    )
  end
end
