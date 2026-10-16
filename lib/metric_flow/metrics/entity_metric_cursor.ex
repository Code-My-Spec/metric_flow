defmodule MetricFlow.Metrics.EntityMetricCursor do
  @moduledoc "Progress for a successfully persisted entity report family."
  use Ecto.Schema

  schema "entity_metric_cursors" do
    field :account_id, :integer
    field :entity_id, :integer
    field :source_report, :string
    field :report_timezone, :string
    field :through_date, :date
    timestamps(type: :utc_datetime_usec)
  end
end
