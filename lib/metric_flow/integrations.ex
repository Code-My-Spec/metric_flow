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
  alias MetricFlow.Integrations.FacebookAdsAccounts
  alias MetricFlow.Integrations.QuickBooksAccounts
  alias MetricFlow.Integrations.GoogleAccounts
  alias MetricFlow.Integrations.GoogleAdsAccounts
  alias MetricFlow.Integrations.GoogleSearchConsoleSites
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Users.Scope

  @default_providers %{
    google: MetricFlow.Integrations.Providers.Google,
    google_analytics: MetricFlow.Integrations.Providers.GoogleAnalytics,
    google_ads: MetricFlow.Integrations.Providers.GoogleAds,
    google_search_console: MetricFlow.Integrations.Providers.GoogleSearchConsole,
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
      attrs =
        result.token
        |> build_integration_attrs(result.normalized)
        |> maybe_attach_realm_id(callback_params)

      IntegrationRepository.upsert_integration(scope, provider, attrs)
    end
  end

  defp maybe_attach_realm_id(attrs, %{"realmId" => realm_id}) do
    put_in(attrs, [:provider_metadata, :realm_id], realm_id)
  end

  defp maybe_attach_realm_id(attrs, _callback_params), do: attrs

  # Delegates to the strategy's callback/2 to exchange the authorization code
  # for tokens and (optionally) fetch user info. The strategy handles all HTTP
  # interaction, which allows test stubs to return canned responses without
  # network access.
  #
  # After the strategy returns, we normalize the user data through the provider
  # module. If the strategy doesn't return user data (e.g. QuickBooks with
  # OAuth2 strategy and no user_url), we normalize an empty map.
  defp exchange_and_normalize(strategy, config, callback_params, provider_mod) do
    require Logger

    with :ok <- verify_state(config, callback_params),
         {:ok, %{token: token} = result} <- strategy.callback(config, callback_params) do
      user_data = Map.get(result, :user) || %{}
      Logger.warning("[OAuth] strategy.callback result keys=#{inspect(Map.keys(result))}, user_data=#{inspect(user_data)}, type=#{inspect(is_map(user_data))}")

      case provider_mod.normalize_user(user_data) do
        {:ok, normalized} ->
          {:ok, %{token: token, normalized: normalized}}

        {:error, reason} = err ->
          Logger.warning("[OAuth] normalize_user failed: #{inspect(reason)}, user_data=#{inspect(user_data)}")
          err
      end
    end
  end

  defp verify_state(config, callback_params) do
    session_params = Keyword.get(config, :session_params, %{})
    stored_state = Map.get(session_params, :state) || Map.get(session_params, "state")
    provided_state = Map.get(callback_params, "state")

    do_verify_state(stored_state, provided_state)
  end

  defp do_verify_state(nil, nil), do: :ok
  defp do_verify_state(nil, _provided), do: {:error, :missing_stored_state}
  defp do_verify_state(state, state), do: :ok
  defp do_verify_state(_stored, _provided), do: {:error, :state_mismatch}

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
  Returns `{:error, :token_refresh_failed}` if an unexpected exception is raised.
  """
  @spec refresh_token(Scope.t(), Integration.t()) ::
          {:ok, Integration.t()} | {:error, term()}
  def refresh_token(%Scope{} = scope, %Integration{} = integration) do
    with {:ok, provider_mod} <- fetch_provider(integration.provider) do
      strategy = provider_mod.strategy()
      config = provider_mod.config()
      token = %{"refresh_token" => integration.refresh_token}

      result =
        if function_exported?(strategy, :refresh_access_token, 2) do
          strategy.refresh_access_token(config, token)
        else
          refresh_config =
            strategy.default_config([])
            |> Keyword.merge(config)
            |> Keyword.put_new(:token_url, token_url_for(integration.provider))
            |> normalize_auth_method()

          AssentOAuth2.refresh_access_token(refresh_config, token)
        end

      case result do
        {:ok, token} ->
          attrs =
            build_integration_attrs(token, %{})
            |> maybe_preserve_refresh_token(integration)
            |> maybe_preserve_provider_metadata(integration)

          IntegrationRepository.update_integration(scope, integration.provider, attrs)

        {:error, reason} ->
          {:error, reason}
      end
    end
  rescue
    _ -> {:error, :token_refresh_failed}
  end

  # Assent OIDC strategies use `client_authentication_method` (string) but
  # OAuth2.grant_access_token expects `:auth_method` (atom).
  @auth_methods %{
    "client_secret_post" => :client_secret_post,
    "client_secret_basic" => :client_secret_basic,
    "client_secret_jwt" => :client_secret_jwt,
    "private_key_jwt" => :private_key_jwt
  }

  defp normalize_auth_method(config) do
    case Keyword.get(config, :client_authentication_method) do
      nil -> config
      method -> Keyword.put_new(config, :auth_method, Map.fetch!(@auth_methods, method))
    end
  end

  # Token endpoints per provider for OAuth2 refresh (not discoverable via OIDC at refresh time)
  defp token_url_for(:google), do: "https://oauth2.googleapis.com/token"
  defp token_url_for(:google_analytics), do: "https://oauth2.googleapis.com/token"
  defp token_url_for(:google_ads), do: "https://oauth2.googleapis.com/token"
  defp token_url_for(:google_search_console), do: "https://oauth2.googleapis.com/token"
  defp token_url_for(:facebook_ads), do: "https://graph.facebook.com/v21.0/oauth/access_token"
  defp token_url_for(:quickbooks), do: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
  defp token_url_for(_), do: "/oauth/token"

  # ---------------------------------------------------------------------------
  # Google account listing
  # ---------------------------------------------------------------------------

  @doc """
  Lists GA4 properties accessible to the user's Google integration.

  Fetches the integration for the `:google` provider, then queries the Google
  Analytics Admin API for available properties. Returns `{:error, :not_found}`
  when no Google integration exists.

  ## Options

    * `:http_plug` - A Plug-compatible function for test injection.
  """
  @spec list_google_accounts(Scope.t(), atom(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_accounts(%Scope{} = scope, provider \\ :google_analytics, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, provider) do
      GoogleAccounts.list_ga4_properties(integration, opts)
    end
  end

  @doc """
  Lists Google Ads customer accounts accessible to the user's Google Ads integration.
  """
  @spec list_google_ads_customers(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_ads_customers(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :google_ads) do
      GoogleAdsAccounts.list_customers(integration, opts)
    end
  end

  @doc """
  Lists verified sites accessible to the user's Google Search Console integration.
  """
  @spec list_search_console_sites(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_search_console_sites(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :google_search_console) do
      GoogleSearchConsoleSites.list_sites(integration, opts)
    end
  end

  @doc """
  Lists Facebook Ad accounts accessible to the user's Facebook Ads integration.
  """
  @spec list_facebook_ads_accounts(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_facebook_ads_accounts(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :facebook_ads) do
      FacebookAdsAccounts.list_accounts(integration, opts)
    end
  end

  @doc """
  Lists income accounts from the QuickBooks Chart of Accounts.
  """
  @spec list_quickbooks_accounts(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_quickbooks_accounts(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :quickbooks) do
      QuickBooksAccounts.list_income_accounts(integration, opts)
    end
  end

  @doc """
  Updates the provider_metadata for an existing integration.

  Merges the given metadata map into the existing provider_metadata, preserving
  fields not included in the update. Used for saving account selections (e.g.
  GA4 property_id) after OAuth connection.
  """
  @spec update_provider_metadata(Scope.t(), atom(), map()) ::
          {:ok, Integration.t()} | {:error, term()}
  def update_provider_metadata(%Scope{} = scope, provider, new_metadata) when is_map(new_metadata) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, provider) do
      merged = Map.merge(integration.provider_metadata || %{}, new_metadata)
      IntegrationRepository.update_integration(scope, provider, %{provider_metadata: merged})
    end
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
    %{
      access_token: Map.get(token, "access_token"),
      refresh_token: Map.get(token, "refresh_token"),
      expires_at: calculate_expires_at(token),
      granted_scopes: parse_scopes(Map.get(token, "scope")),
      provider_metadata: Map.new(normalized_user)
    }
  end

  # Keep the existing refresh_token if the token response didn't include a new one.
  # Google only returns refresh_token on the initial authorization, not on refresh.
  defp maybe_preserve_refresh_token(%{refresh_token: nil} = attrs, %{refresh_token: existing})
       when is_binary(existing) and existing != "" do
    %{attrs | refresh_token: existing}
  end

  defp maybe_preserve_refresh_token(attrs, _integration), do: attrs

  # Keep existing provider_metadata during token refresh — the refresh response
  # has no user data, so build_integration_attrs produces an empty map.
  defp maybe_preserve_provider_metadata(%{provider_metadata: meta} = attrs, %{provider_metadata: existing})
       when meta == %{} and is_map(existing) and existing != %{} do
    %{attrs | provider_metadata: existing}
  end

  defp maybe_preserve_provider_metadata(attrs, _integration), do: attrs

  defp calculate_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end

  defp calculate_expires_at(_token) do
    DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(scopes) when is_list(scopes), do: scopes

  defp parse_scopes(scopes) when is_binary(scopes) do
    split_scope_string(scopes)
  end

  defp split_scope_string(scopes) when is_binary(scopes) do
    case String.contains?(scopes, ",") do
      true -> split_and_trim(scopes, ",")
      false -> split_and_trim(scopes, " ")
    end
  end

  defp split_and_trim(scopes, separator) do
    scopes
    |> String.split(separator)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
