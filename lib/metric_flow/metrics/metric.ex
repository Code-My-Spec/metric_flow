defmodule MetricFlow.Metrics.Metric do
  @moduledoc """
  Ecto schema representing a unified metric data point.

  Stores a single time-series observation from an external provider, including
  the high-level metric_type category (e.g. "traffic", "advertising",
  "financial"), the specific metric_name (e.g. "sessions", "clicks",
  "revenue"), the numeric value, the UTC timestamp when it was recorded, the
  originating provider, and an optional dimensions map for arbitrary breakdown
  attributes (source, campaign, page, etc.).

  Belongs to a User. Indexed on [user_id, provider],
  [user_id, metric_name, recorded_at], and [user_id, metric_type] for
  efficient per-user querying.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          metric_type: String.t() | nil,
          metric_name: String.t() | nil,
          value: float() | nil,
          recorded_at: DateTime.t() | nil,
          provider: atom() | nil,
          dimensions: map() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [:google_analytics, :google_ads, :facebook_ads, :quickbooks]

  schema "metrics" do
    field :metric_type, :string
    field :metric_name, :string
    field :value, :float
    field :recorded_at, :utc_datetime_usec
    field :provider, Ecto.Enum, values: @providers
    field :dimensions, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating a Metric record.

  Validates all required fields and type constraints. Enforces the association
  constraint on user to ensure the referenced user exists in the database.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [
      :user_id,
      :metric_type,
      :metric_name,
      :value,
      :recorded_at,
      :provider,
      :dimensions
    ])
    |> validate_required([:user_id, :metric_type, :metric_name, :value, :recorded_at, :provider])
    |> validate_dimensions()
    |> assoc_constraint(:user)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_dimensions(changeset) do
    case get_change(changeset, :dimensions) do
      nil -> changeset
      value when is_map(value) -> changeset
      _other -> add_error(changeset, :dimensions, "is invalid")
    end
  end
end
