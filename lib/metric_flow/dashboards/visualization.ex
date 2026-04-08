defmodule MetricFlow.Dashboards.Visualization do
  @moduledoc """
  Ecto schema for a standalone, reusable Vega-Lite visualization.

  Stores the display name, owner (user_id), the raw vega_spec JSON map, and
  a shareable boolean that controls whether other users can access this
  visualization. A single Visualization may appear in many dashboards via the
  DashboardVisualization join schema.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          user_id: integer() | nil,
          vega_spec: map() | nil,
          shareable: boolean(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          dashboard_visualizations:
            [MetricFlow.Dashboards.DashboardVisualization.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "visualizations" do
    field :name, :string
    field :vega_spec, :map
    field :shareable, :boolean, default: false

    belongs_to :user, User
    has_many :visualization_metrics, MetricFlow.Dashboards.VisualizationMetric
    has_many :dashboard_visualizations, MetricFlow.Dashboards.DashboardVisualization

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a Visualization record.

  Validates required fields (name, user_id, vega_spec), enforces name length
  between 1 and 255 characters, defaults shareable to false, and adds an
  association constraint ensuring the referenced user exists.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(visualization, attrs) do
    visualization
    |> cast(attrs, [:name, :user_id, :vega_spec, :shareable])
    |> validate_required([:name, :user_id, :vega_spec])
    |> validate_length(:name, min: 1, max: 255)
    |> assoc_constraint(:user)
  end

  @doc """
  Returns whether the visualization is marked as shareable.

  Returns true when shareable is true, false for any other value including nil.
  """
  @spec shareable?(t()) :: boolean()
  def shareable?(%__MODULE__{shareable: true}), do: true
  def shareable?(%__MODULE__{}), do: false
end
