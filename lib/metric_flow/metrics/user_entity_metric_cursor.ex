defmodule MetricFlow.Metrics.UserEntityMetricCursor do
  @moduledoc """
  Sync checkpoint for one user's provider metric on one external entity.

  `synced_through` is the most recent day fully processed. A cursor is scoped
  to a metric as well as an entity so independent series cannot advance one
  another's checkpoint.
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
          provider: atom() | nil,
          entity_id: String.t() | nil,
          metric_name: String.t() | nil,
          synced_through: Date.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "entity_metric_sync_cursors" do
    field :provider, Ecto.Enum, values: @providers, default: :google_business
    field :entity_id, :string
    field :metric_name, :string
    field :synced_through, :date
    belongs_to :user, User
    timestamps(type: :utc_datetime_usec)
  end

  @doc "Validates a checkpoint for a user supplied by the caller."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = cursor, attrs) when is_map(attrs) do
    cursor
    |> cast(attrs, [:provider, :entity_id, :metric_name, :synced_through])
    |> validate_required([:user_id, :provider, :entity_id, :metric_name, :synced_through])
    |> validate_length(:entity_id, min: 1, max: 1024)
    |> validate_length(:metric_name, min: 1, max: 255)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :provider, :entity_id, :metric_name],
      name: :entity_metric_sync_cursors_identity_index
    )
  end
end
