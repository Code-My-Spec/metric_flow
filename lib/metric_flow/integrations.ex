defmodule MetricFlow.Integrations do
  @moduledoc """
  Context module for managing OAuth provider integrations.

  Orchestrates OAuth flows using Assent strategies and provider implementations,
  persisting tokens and user metadata through the IntegrationRepository.

  ## OAuth Flow

  ### Request Phase
  1. User initiates connection to a provider (e.g., GitHub)
  2. `authorize_url/2` generates OAuth authorization URL
  3. User is redirected to provider for consent
  4. Session params are stored for callback verification

  ### Callback Phase
  1. Provider redirects back with authorization code
  2. `handle_callback/3` exchanges code for tokens
  3. Provider normalizes user data
  4. Integration is upserted with encrypted tokens

  ## Provider Support

  Providers must implement `MetricFlow.Integrations.Providers.Behaviour`:
  - `config/0` - Returns Assent configuration
  - `strategy/0` - Returns Assent strategy module
  - `normalize_user/1` - Transforms provider user data to domain model
  """

  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Users.Scope

  @providers %{
    github: MetricFlow.Integrations.Providers.GitHub,
    google: MetricFlow.Integrations.Providers.Google
  }

  @doc """
  Generates OAuth authorization URL for the specified provider.

  Returns the authorization URL to redirect the user to and session params
  that must be stored and passed back during callback.

  ## Examples

      iex> authorize_url(:github)
      {:ok, %{url: "https://github.com/login/oauth/authorize?...", session_params: %{...}}}

      iex> authorize_url(:unsupported)
      {:error, :unsupported_provider}
  """
  def authorize_url(provider) do
    with {:ok, provider_module} <- get_provider_module(provider),
         config <- provider_module.config(),
         strategy <- provider_module.strategy() do
      strategy.authorize_url(config)
    end
  end

  @doc """
  Handles OAuth callback and creates or updates integration.

  Exchanges authorization code for access token, normalizes user data,
  and upserts the integration for the authenticated user.

  ## Parameters
  - `scope` - User scope for multi-tenant isolation
  - `provider` - Provider identifier (:github, :gitlab, :bitbucket)
  - `callback_params` - Query params from OAuth callback including code and state
  - `session_params` - Session params from authorize_url that were stored

  ## Examples

      iex> handle_callback(scope, :github, %{"code" => "..."}, %{...})
      {:ok, %Integration{provider: :github}}

      iex> handle_callback(scope, :github, %{"error" => "access_denied"}, %{})
      {:error, "access_denied"}
  """
  def handle_callback(%Scope{} = scope, provider, callback_params, session_params) do
    with {:ok, provider_module} <- get_provider_module(provider),
         {:ok, token_response} <-
           exchange_code_for_token(provider_module, callback_params, session_params),
         {:ok, normalized_user} <- provider_module.normalize_user(token_response.user),
         {:ok, integration} <-
           persist_integration(scope, provider, token_response, normalized_user) do
      {:ok, integration}
    end
  end

  @doc """
  Retrieves integration for the scoped user and provider.

  Delegates to IntegrationRepository for data access.

  ## Examples

      iex> get_integration(scope, :github)
      {:ok, %Integration{provider: :github}}
  """
  defdelegate get_integration(scope, provider), to: IntegrationRepository

  @doc """
  Lists all integrations for the scoped user.

  ## Examples

      iex> list_integrations(scope)
      [%Integration{provider: :github}, %Integration{provider: :gitlab}]
  """
  defdelegate list_integrations(scope), to: IntegrationRepository

  @doc """
  Removes integration for the scoped user and provider.

  ## Examples

      iex> delete_integration(scope, :github)
      {:ok, %Integration{}}
  """
  defdelegate delete_integration(scope, provider), to: IntegrationRepository

  @doc """
  Checks if user is connected to the specified provider.

  ## Examples

      iex> connected?(scope, :github)
      true
  """
  defdelegate connected?(scope, provider), to: IntegrationRepository

  # Private Helpers

  defp get_provider_module(provider) do
    case Map.get(@providers, provider) do
      nil -> {:error, :unsupported_provider}
      module -> {:ok, module}
    end
  end

  defp exchange_code_for_token(provider_module, callback_params, session_params) do
    config =
      provider_module.config()
      |> Keyword.put(:session_params, session_params)

    strategy = provider_module.strategy()

    case strategy.callback(config, callback_params) do
      {:ok, %{user: user, token: token}} ->
        {:ok, Map.put(token, :user, user)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_integration(scope, provider, token_response, normalized_user) do
    integration_attrs = %{
      access_token: token_response["access_token"],
      refresh_token: token_response["refresh_token"],
      expires_at: calculate_expires_at(token_response),
      granted_scopes: parse_scopes(token_response["scope"]),
      provider_metadata: normalized_user
    }

    IntegrationRepository.upsert_integration(scope, provider, integration_attrs)
  end

  defp calculate_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    DateTime.utc_now()
    |> DateTime.add(expires_in, :second)
  end

  defp calculate_expires_at(_), do: DateTime.utc_now() |> DateTime.add(365, :day)

  defp parse_scopes(nil), do: []
  defp parse_scopes(scope) when is_binary(scope), do: String.split(scope, ~r/[,\s]+/, trim: true)
  defp parse_scopes(scopes) when is_list(scopes), do: scopes
  defp parse_scopes(_), do: []
end
