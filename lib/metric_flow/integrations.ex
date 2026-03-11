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

  require Logger

  alias Assent.Strategy.OAuth2, as: AssentOAuth2
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Users.Scope

  @default_providers %{
    google: MetricFlow.Integrations.Providers.Google,
    facebook_ads: MetricFlow.Integrations.Providers.Facebook,
    quickbooks: MetricFlow.Integrations.Providers.QuickBooks
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

  @doc """
  Disconnects an integration by revoking tokens with the provider (if
  supported) and then deleting the local integration record.

  Token revocation is best-effort — the integration is deleted even if
  revocation fails, since the user's intent is to disconnect.
  """
  @spec disconnect(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, term()}
  def disconnect(%Scope{} = scope, provider) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, provider) do
      revoke_provider_token(provider, integration)
      IntegrationRepository.delete_integration(scope, provider)
    end
  end

  defp revoke_provider_token(provider, integration) do
    with {:ok, provider_mod} <- fetch_provider(provider),
         true <- function_exported?(provider_mod, :revoke_token, 1),
         token when is_binary(token) <- integration.refresh_token || integration.access_token do
      case provider_mod.revoke_token(token) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Token revocation failed for #{provider}: #{inspect(reason)}")
      end
    end
  end

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
  @spec authorize_url(atom(), keyword()) ::
          {:ok, %{url: String.t(), session_params: map()}}
          | {:error, :unsupported_provider}
          | {:error, term()}
  def authorize_url(provider, opts \\ []) do
    with {:ok, provider_mod} <- fetch_provider(provider) do
      config = provider_mod.config() ++ opts
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
  @spec handle_callback(Scope.t(), atom(), map(), map(), keyword()) ::
          {:ok, Integration.t()} | {:error, term()}
  def handle_callback(%Scope{} = scope, provider, session_params, callback_params, opts \\ []) do
    with {:ok, provider_mod} <- fetch_provider(provider),
         config = build_callback_config(provider_mod, session_params) ++ opts,
         strategy = provider_mod.strategy(),
         {:ok, result} <- exchange_and_normalize(strategy, config, callback_params, provider_mod) do
      attrs = build_integration_attrs(result.token, result.normalized)

      attrs =
        case Map.get(callback_params, "realmId") do
          nil -> attrs
          realm_id -> put_in(attrs, [:provider_metadata, :realm_id], realm_id)
        end

      IntegrationRepository.upsert_integration(scope, provider, attrs)
    end
  end

  # Two-phase callback: exchange code for tokens, then fetch user info if
  # the provider has a user_url configured. Providers like QuickBooks don't
  # expose a userinfo endpoint without OpenID scopes, so they omit user_url
  # and we save tokens without user profile data.
  defp exchange_and_normalize(_strategy, config, callback_params, provider_mod) do
    with :ok <- verify_state(config, callback_params),
         {:ok, token} <- exchange_code_for_token(config, callback_params),
         {:ok, normalized} <- fetch_user_info(config, token, provider_mod) do
      {:ok, %{token: token, normalized: normalized}}
    end
  end

  defp verify_state(config, callback_params) do
    session_params = Keyword.get(config, :session_params, %{})
    stored_state = Map.get(session_params, :state) || Map.get(session_params, "state")
    provided_state = Map.get(callback_params, "state")

    cond do
      is_nil(stored_state) and is_nil(provided_state) -> :ok
      is_nil(stored_state) -> {:error, :missing_stored_state}
      stored_state == provided_state -> :ok
      true -> {:error, :state_mismatch}
    end
  end

  defp exchange_code_for_token(config, callback_params) do
    AssentOAuth2.grant_access_token(
      config,
      "authorization_code",
      code: callback_params["code"],
      redirect_uri: Keyword.get(config, :redirect_uri)
    )
  end

  defp fetch_user_info(config, token, provider_mod) do
    case Keyword.get(config, :user_url) do
      nil ->
        {:ok, %{}}

      user_url ->
        access_token = Map.get(token, "access_token")
        headers = [{"authorization", "Bearer #{access_token}"}]

        with {:ok, %{status: 200, body: user_data}} <-
               Assent.Strategy.http_request(:get, user_url, nil, headers, config) do
          provider_mod.normalize_user(user_data)
        end
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
      config = provider_mod.config()
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
    |> Keyword.put(:session_params, session_params)
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
