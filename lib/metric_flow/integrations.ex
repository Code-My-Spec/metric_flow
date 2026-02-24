defmodule MetricFlow.Integrations do
  @moduledoc """
  OAuth connections to external platforms.

  Public API boundary for the Integrations bounded context. Orchestrates OAuth
  flows using Assent strategies and provider implementations, persisting tokens
  and user metadata through the IntegrationRepository.

  The provider map is read from `Application.get_env(:metric_flow, :oauth_providers)`
  at call time, enabling test overrides without recompilation. Falls back to the
  built-in providers map when no override is set.

  All public functions accept a `%Scope{}` as the first parameter for
  multi-tenant isolation. The exception is get_integration_by_id/1 and
  list_all_active_integrations/0, which are unscoped and intended for
  background workers operating system-wide.
  """

  use Boundary, deps: [MetricFlow], exports: [Integration]

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Users.Scope

  @default_providers %{
    google: MetricFlow.Integrations.Providers.Google
  }

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate get_integration(scope, provider), to: IntegrationRepository
  defdelegate list_integrations(scope), to: IntegrationRepository
  defdelegate list_all_active_integrations(), to: IntegrationRepository
  defdelegate delete_integration(scope, provider), to: IntegrationRepository
  defdelegate connected?(scope, provider), to: IntegrationRepository
  defdelegate get_integration_by_id(id), to: IntegrationRepository

  # ---------------------------------------------------------------------------
  # Provider discovery
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of configured provider atoms.

  Reads the provider map from application config at call time, enabling
  test overrides without recompilation. Falls back to the default providers
  when no override is configured.
  """
  @spec list_providers() :: [atom()]
  def list_providers do
    Application.get_env(:metric_flow, :oauth_providers, @default_providers)
    |> Map.keys()
  end

  # ---------------------------------------------------------------------------
  # OAuth flow
  # ---------------------------------------------------------------------------

  @doc """
  Generates an OAuth authorization URL for the specified provider.

  Looks up the provider module from the providers map (overridable via
  Application config for tests), retrieves the Assent configuration and
  strategy, then delegates to the strategy's `authorize_url/1`.

  Returns `{:ok, %{url: url, session_params: params}}` on success.
  Returns `{:error, :unsupported_provider}` for unknown provider atoms.
  """
  @spec authorize_url(atom()) ::
          {:ok, %{url: String.t(), session_params: map()}}
          | {:error, :unsupported_provider}
          | {:error, term()}
  def authorize_url(provider) do
    with {:ok, provider_mod} <- fetch_provider(provider) do
      config = provider_mod.config() |> Map.new()
      strategy = provider_mod.strategy()
      strategy.authorize_url(config)
    end
  end

  @doc """
  Handles an OAuth callback by exchanging the authorization code for tokens,
  normalizing user data, and upserting the integration record.

  Steps:
  1. Looks up the provider module from the providers map
  2. Merges session_params into the provider config for CSRF validation
  3. Calls the strategy's callback to exchange the code for tokens
  4. Calls the provider's normalize_user/1 to transform user data
  5. Builds integration attributes (tokens, expiry, scopes, metadata)
  6. Persists via IntegrationRepository.upsert_integration/3

  Returns `{:ok, %Integration{}}` on success.
  Returns `{:error, :unsupported_provider}` for unknown provider atoms.
  Returns `{:error, reason}` when token exchange or normalization fails.
  """
  @spec handle_callback(Scope.t(), atom(), map(), map()) ::
          {:ok, Integration.t()} | {:error, term()}
  def handle_callback(%Scope{} = scope, provider, session_params, callback_params) do
    with {:ok, provider_mod} <- fetch_provider(provider),
         config = build_callback_config(provider_mod, session_params),
         strategy = provider_mod.strategy(),
         {:ok, %{token: token, user: user_data}} <- strategy.callback(config, callback_params),
         {:ok, normalized} <- provider_mod.normalize_user(user_data) do
      attrs = build_integration_attrs(token, normalized)
      IntegrationRepository.upsert_integration(scope, provider, attrs)
    end
  end

  @doc """
  Attempts to refresh the OAuth access token for an integration using the
  stored refresh token.

  Looks up the OAuth provider module based on the integration's provider field
  and exchanges the refresh token for a new access token. Updates the
  integration record with the fresh tokens and expiry on success.

  Returns `{:ok, integration}` with updated tokens on success.
  Returns `{:error, :unsupported_provider}` when the integration's provider has
  no OAuth provider module registered.
  Returns `{:error, reason}` when the token refresh request fails or the
  provider strategy does not support refresh.
  """
  @spec refresh_token(Scope.t(), Integration.t()) ::
          {:ok, Integration.t()} | {:error, term()}
  def refresh_token(%Scope{} = scope, %Integration{} = integration) do
    with {:ok, provider_mod} <- fetch_provider(integration.provider) do
      config = Map.new(provider_mod.config())
      strategy = provider_mod.strategy()

      case strategy.refresh_access_token(config, %{"refresh_token" => integration.refresh_token}) do
        {:ok, token} ->
          attrs = build_integration_attrs(token, %{})
          IntegrationRepository.update_integration(scope, integration.provider, attrs)

        {:error, reason} ->
          {:error, reason}
      end
    end
  rescue
    _ -> {:error, :token_refresh_failed}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fetch_provider(provider) do
    providers = Application.get_env(:metric_flow, :oauth_providers, @default_providers)

    case Map.fetch(providers, provider) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, :unsupported_provider}
    end
  end

  defp build_callback_config(provider_mod, session_params) do
    provider_mod.config()
    |> Map.new()
    |> Map.merge(session_params)
  end

  defp build_integration_attrs(token, normalized_user) do
    expires_at = calculate_expires_at(token)
    granted_scopes = parse_scopes(Map.get(token, "scope"))

    %{
      access_token: Map.get(token, "access_token"),
      refresh_token: Map.get(token, "refresh_token"),
      expires_at: expires_at,
      granted_scopes: granted_scopes,
      provider_metadata: Map.new(normalized_user)
    }
  end

  defp calculate_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end

  defp calculate_expires_at(_token) do
    DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)
  end

  defp parse_scopes(nil), do: []

  defp parse_scopes(scopes) when is_list(scopes), do: scopes

  defp parse_scopes(scopes) when is_binary(scopes) do
    separator = if String.contains?(scopes, ","), do: ",", else: " "

    scopes
    |> String.split(separator)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
