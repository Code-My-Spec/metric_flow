defmodule MetricFlow.Integrations.Providers.Google do
  @moduledoc """
  Google provider implementation for OAuth integration.

  Implements the `MetricFlow.Integrations.Providers.Behaviour` to provide
  Google-specific OAuth configuration using Assent's built-in Google strategy
  and normalizes Google user data to the application's domain model.

  ## Configuration

  Requires the following application config:
  - `:google_client_id` - OAuth client ID from Google Cloud Console
  - `:google_client_secret` - OAuth client secret from Google Cloud Console
  - `:oauth_base_url` - Base URL for OAuth callbacks

  ## OAuth Flow

  This provider leverages `Assent.Strategy.Google` for OAuth implementation,
  providing only Google-specific configuration and user data normalization.

  ## Scopes

  Requests the following Google OAuth scopes:
  - `email` - Access to user email address
  - `profile` - Access to user profile information
  - `https://www.googleapis.com/auth/analytics.readonly` - Read-only access to Google Analytics
  """

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @impl true
  def config do
    require Logger

    client_id = Application.fetch_env!(:metric_flow, :google_client_id)
    client_secret = Application.fetch_env!(:metric_flow, :google_client_secret)
    redirect_uri = build_redirect_uri()

    Logger.debug("Google OAuth Config - client_id: #{inspect(client_id)}")
    Logger.debug("Google OAuth Config - client_secret present: #{!is_nil(client_secret)}")
    Logger.debug("Google OAuth Config - redirect_uri: #{redirect_uri}")

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "email profile https://www.googleapis.com/auth/analytics.edit",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Google

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: Map.get(user_data, "email"),
         name: Map.get(user_data, "name"),
         username: Map.get(user_data, "email"),
         avatar_url: Map.get(user_data, "picture"),
         hosted_domain: Map.get(user_data, "hd")
       }}
    end
  end

  def normalize_user(_), do: {:error, :invalid_user_data}

  defp extract_provider_user_id(user_data) do
    case Map.get(user_data, "sub") do
      nil -> {:error, :missing_provider_user_id}
      id when is_binary(id) -> {:ok, id}
      id when is_integer(id) -> {:ok, to_string(id)}
      _ -> {:error, :invalid_provider_user_id}
    end
  end

  defp build_redirect_uri do
    base_url = Application.fetch_env!(:metric_flow, :oauth_base_url)
    "#{base_url}/auth/google/callback"
  end
end
