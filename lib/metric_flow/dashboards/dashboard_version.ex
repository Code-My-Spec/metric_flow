defmodule MetricFlow.Dashboards.DashboardVersion do
  @moduledoc """
  A snapshot of a dashboard's visualizations at one point in time.

  Story 74, rule 7: every change the agent makes to a dashboard is stored
  as a version. Each record freezes the full visualization list (the same
  shape `DashboardLive.Editor` keeps in memory) so an earlier version can
  later be restored. Immutable once written -- there is no changeset for
  updating one, only creating it.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Dashboards.Dashboard

  @type t :: %__MODULE__{
          id: integer() | nil,
          visualizations: [map()],
          dashboard_id: integer() | nil,
          dashboard: Dashboard.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil
        }

  schema "dashboard_versions" do
    field :visualizations, {:array, :map}

    belongs_to :dashboard, Dashboard

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Creates an Ecto changeset for a new DashboardVersion snapshot.

  Requires `dashboard_id` and `visualizations`, and adds an association
  constraint on `dashboard` to ensure the referenced dashboard exists.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(dashboard_version, attrs) do
    dashboard_version
    |> cast(attrs, [:dashboard_id, :visualizations])
    |> validate_required([:dashboard_id, :visualizations])
    |> assoc_constraint(:dashboard)
  end
end
