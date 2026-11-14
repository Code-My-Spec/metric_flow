defmodule MetricFlow.Metrics.EntityMetricObservation do
  @moduledoc "A dated observation whose account and entity are assigned by the repository."
  use Ecto.Schema
  import Ecto.Changeset

  schema "entity_metric_observations" do
    field :account_id, :integer
    field :entity_id, :integer
    field :metric_name, :string
    field :report_date, :date
    field :report_timezone, :string
    field :measurement_kind, :string
    field :breakdown_type, :string, default: "total"
    field :breakdown_key, :string, default: "all"
    field :value, :decimal
    field :unit, :string
    field :source_report, :string
    field :fetched_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [
      :metric_name,
      :report_date,
      :report_timezone,
      :measurement_kind,
      :breakdown_type,
      :breakdown_key,
      :value,
      :unit,
      :source_report,
      :fetched_at
    ])
    |> validate_required([
      :account_id,
      :entity_id,
      :metric_name,
      :report_date,
      :report_timezone,
      :measurement_kind,
      :breakdown_type,
      :breakdown_key,
      :value,
      :unit,
      :source_report,
      :fetched_at
    ])
    |> validate_inclusion(:measurement_kind, ["daily", "snapshot"])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:entity_id, name: :entity_observations_account_entity)
    |> check_constraint(:measurement_kind, name: :entity_observations_kind)
    |> check_constraint(:breakdown_key, name: :entity_observations_total_key)
    |> unique_constraint(
      [
        :account_id,
        :entity_id,
        :metric_name,
        :report_date,
        :report_timezone,
        :measurement_kind,
        :breakdown_type,
        :breakdown_key
      ],
      name: :entity_observations_identity
    )
  end
end
