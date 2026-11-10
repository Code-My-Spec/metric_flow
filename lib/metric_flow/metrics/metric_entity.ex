defmodule MetricFlow.Metrics.MetricEntity do
  @moduledoc """
  A named external entity whose metrics belong to one user.

  Provider and entity ID identify a location within a user's data. The
  observations retain their own entity IDs so historical values remain
  attributable even when an entity's display name changes.
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
          display_name: String.t(),
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "user_metric_entities" do
    field :provider, Ecto.Enum, values: @providers, default: :google_business
    field :entity_id, :string
    field :display_name, :string, default: ""
    field :metadata, :map, default: %{}
    belongs_to :user, User
    timestamps(type: :utc_datetime_usec)
  end

  @doc "Validates an external entity for the owner set on the struct."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = entity, attrs) when is_map(attrs) do
    entity
    |> cast(attrs, [:provider, :entity_id, :display_name, :metadata])
    |> validate_required([:user_id, :provider, :entity_id])
    |> validate_length(:entity_id, min: 1, max: 1024)
    |> validate_length(:display_name, max: 255)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :provider, :entity_id],
      name: :user_metric_entities_identity_index
    )
  end
end
