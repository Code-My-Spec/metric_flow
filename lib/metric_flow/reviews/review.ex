defmodule MetricFlow.Reviews.Review do
  @moduledoc """
  Ecto schema representing an individual customer review.

  Stores integration_id, provider, external_review_id, reviewer_name,
  star_rating (1-5), comment text, review_date, location_id, and metadata
  map for provider-specific fields. Belongs to User via integration. Indexed
  on [user_id, provider], [user_id, review_date], and [external_review_id]
  for deduplication during sync.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          integration_id: integer() | nil,
          integration: Integration.t() | Ecto.Association.NotLoaded.t(),
          provider: atom() | nil,
          external_review_id: String.t() | nil,
          reviewer_name: String.t() | nil,
          star_rating: integer() | nil,
          comment: String.t() | nil,
          review_date: Date.t() | nil,
          location_id: String.t() | nil,
          metadata: map() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [:google_business]

  schema "reviews" do
    field :provider, Ecto.Enum, values: @providers
    field :external_review_id, :string
    field :reviewer_name, :string
    field :star_rating, :integer
    field :comment, :string
    field :review_date, :date
    field :location_id, :string
    field :metadata, :map, default: %{}

    belongs_to :user, User
    belongs_to :integration, Integration

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a Review record.

  Validates all required fields, type constraints, and enforces the
  association constraints on user and integration to ensure the referenced
  records exist in the database.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :integration_id,
      :user_id,
      :provider,
      :external_review_id,
      :reviewer_name,
      :star_rating,
      :comment,
      :review_date,
      :location_id,
      :metadata
    ])
    |> validate_required([
      :integration_id,
      :user_id,
      :provider,
      :external_review_id,
      :star_rating,
      :review_date
    ])
    |> validate_number(:star_rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_metadata()
    |> assoc_constraint(:user)
    |> assoc_constraint(:integration)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_metadata(changeset) do
    case get_change(changeset, :metadata) do
      nil -> changeset
      value when is_map(value) -> changeset
      _other -> add_error(changeset, :metadata, "is invalid")
    end
  end
end
