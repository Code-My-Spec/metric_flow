defmodule MetricFlow.Integrations.Providers.GitHub do
  @moduledoc """
  GitHub provider implementation for OAuth integration.

  Implements the `MetricFlow.Integrations.Providers.Behaviour` to provide
  GitHub-specific OAuth configuration using Assent's built-in GitHub strategy
  and normalizes GitHub user data to the application's domain model.

  ## Configuration

  Requires the following application config:
  - `:github_client_id` - OAuth client ID from GitHub
  - `:github_client_secret` - OAuth client secret from GitHub
  - `:oauth_base_url` - Base URL for OAuth callbacks

  ## OAuth Flow

  This provider leverages `Assent.Strategy.Github` for OAuth implementation,
  providing only GitHub-specific configuration and user data normalization.

  ## Scopes

  Requests the following GitHub OAuth scopes:
  - `user:email` - Access to user email addresses
  - `repo` - Full control of private repositories (user can select specific repos during OAuth)
  """

  @behaviour MetricFlow.Integrations.Providers.Behaviour

  @impl true
  def config do
    [
      client_id: Application.fetch_env!(:metric_flow, :github_client_id),
      client_secret: Application.fetch_env!(:metric_flow, :github_client_secret),
      redirect_uri: build_redirect_uri(),
      authorization_params: [
        scope: "user:email repo"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Github

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: Map.get(user_data, "email"),
         name: Map.get(user_data, "name"),
         username: Map.get(user_data, "preferred_username"),
         avatar_url: Map.get(user_data, "picture")
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
    "#{base_url}/auth/github/callback"
  end
end
