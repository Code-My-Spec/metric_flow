defmodule MetricFlow.Metrics.DerivedMetricDefinition do
  @moduledoc """
  A user-defined derived metric: a name plus the two raw component metric
  names its value is computed from (numerator / denominator).

  Lets an agency admin add a new calculated metric type -- e.g. CPA =
  total_cost / conversions -- as data, without an engineer changing the
  dashboard's aggregation code.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Users.User

  @type t :: %__MODULE__{}

  schema "derived_metric_definitions" do
    field :name, :string
    field :numerator, :string
    field :denominator, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(derived_metric_definition, attrs) do
    derived_metric_definition
    |> cast(attrs, [:name, :numerator, :denominator, :user_id])
    |> validate_required([:name, :numerator, :denominator, :user_id])
    |> unique_constraint([:user_id, :name])
  end
end
