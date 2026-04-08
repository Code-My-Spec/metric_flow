defmodule MetricFlow.Dashboards.VisualizationMetric do
  @moduledoc """
  Join schema binding a Visualization to a metric by name.

  A visualization can display one or more metrics. Each bound metric
  has a role — "primary" for the main series, or other roles for
  comparison/overlay series. At render time, data for each bound metric
  is fetched from the Metrics context and injected into the spec.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Dashboards.Visualization

  @type t :: %__MODULE__{
          id: integer() | nil,
          visualization_id: integer() | nil,
          metric_name: String.t() | nil,
          role: String.t(),
          visualization: Visualization.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "visualization_metrics" do
    field :metric_name, :string
    field :role, :string, default: "primary"

    belongs_to :visualization, Visualization

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(visualization_metric, attrs) do
    visualization_metric
    |> cast(attrs, [:visualization_id, :metric_name, :role])
    |> validate_required([:visualization_id, :metric_name])
    |> unique_constraint([:visualization_id, :metric_name])
    |> assoc_constraint(:visualization)
  end
end
