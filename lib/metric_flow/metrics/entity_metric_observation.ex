defmodule MetricFlow.Metrics.EntityMetricObservation do
  @moduledoc """
  One daily metric value for a user's external entity.

  The identity includes the provider, entity, metric, and day so a corrected
  provider value can replace the earlier observation without adding a duplicate.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Users.User

  @providers [
    :google_analytics,
    :google_ads,
    :google_search_console,
    :google_business,
    :google_business_reviews,
    :facebook_ads,
    :quickbooks
  ]

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          provider: atom(),
          entity_id: String.t() | nil,
          metric_name: String.t() | nil,
          observed_on: Date.t() | nil,
          value: float() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "entity_metric_observations" do
    field :provider, Ecto.Enum, values: @providers, default: :google_business
    field :entity_id, :string
    field :metric_name, :string
    field :observed_on, :date
    field :value, :float
    belongs_to :user, User
    timestamps(type: :utc_datetime_usec)
  end

  @doc "Validates a daily value for the user supplied by the caller."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = observation, attrs) when is_map(attrs) do
    observation
    |> cast(attrs, [:provider, :entity_id, :metric_name, :observed_on, :value])
    |> validate_required([:user_id, :provider, :entity_id, :metric_name, :observed_on, :value])
    |> validate_length(:entity_id, min: 1, max: 1024)
    |> validate_length(:metric_name, min: 1, max: 255)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :provider, :entity_id, :metric_name, :observed_on],
      name: :entity_metric_observations_identity_index
    )
  end
end
