defmodule MetricFlow.Dashboards.DashboardVisualization do
  @moduledoc """
  Ecto schema representing the many-to-many junction between a Dashboard and a Visualization.

  Stores dashboard_id, visualization_id, position (integer display order), and size
  (layout hint string). Enforces a unique constraint on {dashboard_id, visualization_id}
  so a given visualization can only appear once per dashboard.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.Visualization

  @type t :: %__MODULE__{
          id: integer() | nil,
          dashboard_id: integer() | nil,
          visualization_id: integer() | nil,
          position: integer() | nil,
          size: String.t(),
          dashboard: Dashboard.t() | Ecto.Association.NotLoaded.t(),
          visualization: Visualization.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_sizes ["small", "medium", "large", "full"]

  schema "dashboard_visualizations" do
    field :position, :integer
    field :size, :string, default: "medium"

    belongs_to :dashboard, Dashboard
    belongs_to :visualization, Visualization

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a DashboardVisualization record.

  Validates required fields (dashboard_id, visualization_id, position), enforces
  position is non-negative, validates size is one of the permitted layout hint values,
  and enforces the unique constraint on the dashboard/visualization pair.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(dashboard_visualization, attrs) do
    dashboard_visualization
    |> cast(attrs, [:dashboard_id, :visualization_id, :position, :size])
    |> validate_required([:dashboard_id, :visualization_id, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_inclusion(:size, @valid_sizes)
    |> assoc_constraint(:dashboard)
    |> assoc_constraint(:visualization)
    |> unique_constraint([:dashboard_id, :visualization_id],
      name: :dashboard_visualizations_dashboard_id_visualization_id_index
    )
  end
end
