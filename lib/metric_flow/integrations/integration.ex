defmodule MetricFlow.Integrations.Integration do
  @moduledoc """
  Represents OAuth integration connections between users and external service providers.

  Stores encrypted access and refresh tokens with automatic expiration tracking.
  Each integration maintains provider-specific metadata and granted scopes while
  ensuring one connection per provider per user.

  ## Security
  - access_token and refresh_token are encrypted at rest using Cloak.Ecto.Binary
  - Tokens are never exposed in logs or error messages
  - expires_at enables expiration detection without decrypting tokens

  ## Business Rules
  - One integration per provider per user (enforced by unique constraint)
  - Reconnecting to same provider updates existing integration via upsert
  - Token refresh is synchronous on-demand when get_token/2 detects expiration
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "integrations" do
    field :provider, Ecto.Enum, values: [:github, :gitlab, :bitbucket, :google]
    field :access_token, MetricFlow.Encrypted.Binary
    field :refresh_token, MetricFlow.Encrypted.Binary
    field :expires_at, :utc_datetime_usec
    field :granted_scopes, {:array, :string}, default: []
    field :provider_metadata, :map, default: %{}

    belongs_to :user, MetricFlow.Users.User

    timestamps(type: :utc_datetime_usec)
  end

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
    |> unique_constraint([:user_id, :provider],
      name: :integrations_user_id_provider_index,
      message: "already exists for this user"
    )
  end

  defp validate_provider_metadata(changeset) do
    case get_field(changeset, :provider_metadata) do
      nil ->
        changeset

      metadata when is_map(metadata) ->
        changeset

      _ ->
        add_error(changeset, :provider_metadata, "must be a map")
    end
  end

  @doc """
  Checks if the access token has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Checks if a refresh token is available.
  """
  def has_refresh_token?(%__MODULE__{refresh_token: nil}), do: false
  def has_refresh_token?(%__MODULE__{refresh_token: _}), do: true
end
