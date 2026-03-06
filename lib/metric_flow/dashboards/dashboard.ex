defmodule MetricFlow.Dashboards.Dashboard do
  @moduledoc """
  Ecto schema representing a named collection of visualizations.

  Stores name, owner (user_id), and a built_in boolean flag that marks
  system-provided canned dashboards. Belongs to User and has many
  DashboardVisualizations, with a through-association to Visualizations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Dashboards.DashboardVisualization
  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          built_in: boolean(),
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          dashboard_visualizations:
            [DashboardVisualization.t()] | Ecto.Association.NotLoaded.t(),
          visualizations: [Visualization.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "dashboards" do
    field :name, :string
    field :description, :string
    field :built_in, :boolean, default: false

    belongs_to :user, User
    has_many :dashboard_visualizations, DashboardVisualization
    has_many :visualizations, through: [:dashboard_visualizations, :visualization]

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a Dashboard record.

  Validates required fields (name, user_id), length constraints on name
  (1–255 characters) and description (max 1000 characters), and adds an
  association constraint on user to ensure the referenced user exists.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(dashboard, attrs) do
    dashboard
    |> cast(attrs, [:name, :description, :user_id, :built_in])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
    |> assoc_constraint(:user)
  end

  @doc """
  Returns true if the dashboard is a system-provided canned dashboard.

  Returns false for user-created dashboards.
  """
  @spec built_in?(t()) :: boolean()
  def built_in?(%__MODULE__{built_in: true}), do: true
  def built_in?(%__MODULE__{}), do: false
end
