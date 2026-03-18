defmodule MetricFlow.Integrations.Integration do
  @moduledoc """
  Ecto schema representing OAuth integration connections between users and
  external service providers.

  Stores encrypted access and refresh tokens with automatic expiration
  tracking. Enforces one integration per provider per user via unique
  constraint. Provides expired?/1 and has_refresh_token?/1 helper functions.

  The provider field stores an atom backed by a string column. Supported
  providers are defined in @providers and validated at the changeset level.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MetricFlow.Encrypted.Binary
  alias MetricFlow.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: atom() | nil,
          access_token: binary() | nil,
          refresh_token: binary() | nil,
          expires_at: DateTime.t() | nil,
          granted_scopes: [String.t()] | nil,
          provider_metadata: map() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers [
    :github,
    :gitlab,
    :bitbucket,
    :google,
    :google_ads,
    :facebook_ads,
    :google_analytics,
    :google_search_console,
    :google_business,
    :google_business_reviews,
    :quickbooks
  ]

  @test_providers Application.compile_env(:metric_flow, :test_providers, [])

  @all_providers @providers ++ @test_providers

  schema "integrations" do
    field :provider, Ecto.Enum, values: @all_providers
    field :access_token, Binary
    field :refresh_token, Binary
    field :expires_at, :utc_datetime_usec
    field :granted_scopes, {:array, :string}, default: []
    field :provider_metadata, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Creates an Ecto changeset for creating or updating an Integration record.

  Validates all required fields, type constraints, and associations. Enforces
  a unique constraint on the user/provider combination to prevent duplicate
  integrations per user.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :user_id,
      :provider,
      :access_token,
      :refresh_token,
      :expires_at,
      :granted_scopes,
      :provider_metadata
    ])
    |> validate_required([:user_id, :provider, :access_token, :expires_at])
    |> validate_provider_metadata()
    |> assoc_constraint(:user)
    |> unique_constraint([:user_id, :provider], name: :integrations_user_id_provider_index, message: "has already been taken")
  end

  @doc """
  Checks if the integration's access token has expired by comparing expires_at
  with the current UTC time.

  Returns true when the token is at or past its expiration time.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}) do
    now = DateTime.utc_now()
    DateTime.compare(now, expires_at) != :lt
  end

  @doc """
  Checks if the integration has a refresh token available for token renewal.

  Returns false when refresh_token is nil or an empty string, true otherwise.
  """
  @spec has_refresh_token?(t()) :: boolean()
  def has_refresh_token?(%__MODULE__{refresh_token: nil}), do: false
  def has_refresh_token?(%__MODULE__{refresh_token: ""}), do: false
  def has_refresh_token?(%__MODULE__{refresh_token: _token}), do: true

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_provider_metadata(changeset) do
    case get_change(changeset, :provider_metadata) do
      nil -> changeset
      value when is_map(value) -> changeset
      _other -> add_error(changeset, :provider_metadata, "is invalid")
    end
  end
end
