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
  alias MetricFlow.Integrations.GoogleAccounts
  alias MetricFlow.Integrations.GoogleAdsAccounts
  alias MetricFlow.Integrations.GoogleBusinessLocations
  alias MetricFlow.Integrations.GoogleSearchConsoleSites
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationRepository
  alias MetricFlow.Integrations.QuickBooksAccounts
  alias MetricFlow.Users.Scope

  @default_providers %{
    youtube: MetricFlow.Integrations.Providers.YouTube,
    google: MetricFlow.Integrations.Providers.Google,
    google_analytics: MetricFlow.Integrations.Providers.GoogleAnalytics,
    google_ads: MetricFlow.Integrations.Providers.GoogleAds,
    google_search_console: MetricFlow.Integrations.Providers.GoogleSearchConsole,
    google_business: MetricFlow.Integrations.Providers.GoogleBusiness,
    facebook_ads: MetricFlow.Integrations.Providers.Facebook,
    quickbooks: MetricFlow.Integrations.Providers.QuickBooks,
    codemyspec: MetricFlow.Integrations.Providers.Codemyspec
  }

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate get_integration(scope, provider), to: IntegrationRepository
  defdelegate list_integrations(scope), to: IntegrationRepository
  defdelegate list_all_active_integrations(), to: IntegrationRepository
  defdelegate delete_integration(scope, provider), to: IntegrationRepository
  defdelegate delete_all_integrations(scope), to: IntegrationRepository
  defdelegate connected?(scope, provider), to: IntegrationRepository
  defdelegate get_integration_by_id(id), to: IntegrationRepository
  defdelegate update_integration(scope, provider, attrs), to: IntegrationRepository

  @doc """
  Disconnects an integration by revoking tokens with the provider (if
  supported) and then deleting the local integration record.

  Token revocation is best-effort — the integration is deleted even if
  revocation fails, since the user's intent is to disconnect.
  """
  @spec disconnect(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, term()}
  def disconnect(%Scope{} = scope, provider) do
    with :ok <- IntegrationRepository.authorize_write(scope, provider),
         {:ok, integration} <- IntegrationRepository.get_integration(scope, provider) do
      revoke_provider_token(provider, integration)
      IntegrationRepository.delete_integration(scope, provider)
    end
  end

  defp revoke_provider_token(provider, integration) do
    with {:ok, provider_mod} <- fetch_provider(provider),
         true <- function_exported?(provider_mod, :revoke_token, 1),
         token when is_binary(token) <- integration.refresh_token || integration.access_token do
      case provider_mod.revoke_token(token) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Token revocation failed for #{provider}: #{inspect(reason)}")
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
      strategy = provider_mod.strategy()
      config = with_static_discovery(provider_mod.config() ++ opts, strategy)
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

  # ---------------------------------------------------------------------------
  # Social login ("Continue with Google")
  # ---------------------------------------------------------------------------

  @doc """
  Authorization URL for Google sign-in (identity scopes only). Same return
  shape as `authorize_url/2`; the provider module can be overridden in tests
  with `config :metric_flow, :google_login_provider`.
  """
  @spec authorize_login_url() ::
          {:ok, %{url: String.t(), session_params: map()}} | {:error, term()}
  def authorize_login_url do
    mod = login_provider()
    mod.strategy().authorize_url(with_static_discovery(mod.config(), mod.strategy()))
  end

  @doc """
  Completes Google sign-in: verifies the CSRF state, exchanges the code and
  returns the normalized Google profile. Persists nothing.

  Returns `{:error, :email_not_verified}` / `{:error, :missing_email}` when Google
  does not vouch for an email address, since the email is how we match accounts.
  """
  @spec handle_login_callback(map(), map()) :: {:ok, map()} | {:error, term()}
  def handle_login_callback(session_params, callback_params) do
    mod = login_provider()
    config =
      mod.config()
      |> with_static_discovery(mod.strategy())
      |> Keyword.put(:session_params, session_params)

    with :ok <- require_state(session_params),
         :ok <- verify_state(config, callback_params),
         {:ok, result} <- mod.strategy().callback(config, callback_params),
         {:ok, normalized} <- mod.normalize_user(Map.get(result, :user) || %{}) do
      case normalized do
        %{email: email} when not is_binary(email) or email == "" -> {:error, :missing_email}
        %{email_verified: false} -> {:error, :email_not_verified}
        _ -> {:ok, normalized}
      end
    end
  end

  # Google's strategy does OIDC discovery over HTTP before every flow. Tests set
  # `:google_openid_configuration` so no request to accounts.google.com is made;
  # unset (dev/prod), discovery runs as normal.
  defp with_static_discovery(config, Assent.Strategy.Google) do
    case Application.get_env(:metric_flow, :google_openid_configuration) do
      nil -> config
      oidc -> Keyword.put_new(config, :openid_configuration, oidc)
    end
  end

  defp with_static_discovery(config, _strategy), do: config

  defp require_state(%{state: s}) when is_binary(s), do: :ok
  defp require_state(%{"state" => s}) when is_binary(s), do: :ok
  defp require_state(_), do: {:error, :missing_stored_state}

  defp login_provider,
    do:
      Application.get_env(
        :metric_flow,
        :google_login_provider,
        MetricFlow.Integrations.Providers.GoogleLogin
      )

  def authorize_youtube_connection(%Scope{} = scope),
    do: IntegrationRepository.authorize_write(scope, :youtube)

  @doc "Exchanges YouTube consent for a short-lived channel-selection authorization."
  def prepare_youtube_connection(%Scope{} = scope, session_params, callback_params) do
    with :ok <- IntegrationRepository.authorize_write(scope, :youtube),
         true <-
           session_params[:youtube_user_id] == scope.user.id and
             session_params[:youtube_account_id] == scope.account_id,
         {:ok, provider_mod} <- fetch_provider(:youtube),
         config = build_callback_config(provider_mod, session_params),
         {:ok, result} <-
           exchange_and_normalize(provider_mod.strategy(), config, callback_params, provider_mod),
         attrs = build_integration_attrs(result.token, result.normalized),
         true <- youtube_scopes_granted?(attrs.granted_scopes),
         {:ok, channels} <-
           MetricFlow.Integrations.YouTubeChannels.list_channels(attrs.access_token) do
      case channels do
        [] ->
          {:error, :no_youtube_channels}

        _ ->
          token =
            MetricFlow.Integrations.PendingYouTubeAuthorizations.put(
              scope.user.id,
              scope.account_id,
              %{attrs: attrs, channels: channels}
            )

          {:ok, token}
      end
    else
      false -> {:error, :invalid_youtube_authorization}
      {:error, _} = error -> error
    end
  end

  def youtube_selection(%Scope{} = scope, pending_token) do
    with :ok <- authorize_youtube_connection(scope) do
      case MetricFlow.Integrations.PendingYouTubeAuthorizations.get(
             pending_token,
             scope.user.id,
             scope.account_id
           ) do
        {:ok, %{attrs: attrs, channels: channels}} ->
          integration =
            struct(
              Integration,
              Map.merge(attrs, %{
                provider: :youtube,
                user_id: scope.user.id,
                account_id: scope.account_id
              })
            )

          if Integration.expired?(integration) do
            {:error, :token_expired}
          else
            {:ok, %{integration: integration, channels: channels, pending?: true}}
          end

        {:error, _} ->
          with {:ok, integration} <- get_integration(scope, :youtube),
               {:ok, integration} <- ensure_fresh_token(scope, integration),
               true <- youtube_scopes_granted?(integration.granted_scopes),
               {:ok, channels} <-
                 MetricFlow.Integrations.YouTubeChannels.list_channels(integration.access_token) do
            {:ok, %{integration: integration, channels: channels, pending?: false}}
          else
            false -> {:error, :missing_youtube_scopes}
            {:error, _} = error -> error
          end
      end
    end
  end

  def save_youtube_channels(%Scope{} = scope, pending_token, channel_ids)
      when is_list(channel_ids) and channel_ids != [] do
    with {:ok, selection} <- youtube_selection(scope, pending_token),
         true <- Enum.all?(channel_ids, &is_binary/1),
         selected = Enum.uniq(channel_ids),
         available = MapSet.new(selection.channels, & &1.id),
         true <- Enum.all?(selected, &MapSet.member?(available, &1)) do
      integration = selection.integration
      metadata = Map.put(integration.provider_metadata || %{}, "channel_ids", selected)

      result =
        if selection.pending? do
          attrs = %{
            access_token: integration.access_token,
            refresh_token: integration.refresh_token,
            expires_at: integration.expires_at,
            granted_scopes: integration.granted_scopes,
            provider_metadata: metadata
          }

          IntegrationRepository.upsert_integration(scope, :youtube, attrs)
        else
          IntegrationRepository.update_integration(scope, :youtube, %{provider_metadata: metadata})
        end

      case result do
        {:ok, saved} ->
          MetricFlow.Integrations.PendingYouTubeAuthorizations.delete(
            pending_token,
            scope.user.id,
            scope.account_id
          )

          {:ok, saved}

        {:error, _} = error ->
          error
      end
    else
      false -> {:error, :invalid_channel_selection}
      {:error, _} = error -> error
    end
  end

  def save_youtube_channels(%Scope{}, _pending_token, _channel_ids),
    do: {:error, :empty_channel_selection}

  def youtube_scopes_granted?(scopes) when is_list(scopes) do
    Enum.all?(MetricFlow.Integrations.Providers.YouTube.required_scopes(), &(&1 in scopes))
  end

  def youtube_scopes_granted?(_), do: false

  def youtube_revenue_granted?(%Integration{granted_scopes: scopes}),
    do: MetricFlow.Integrations.Providers.YouTube.revenue_scope() in (scopes || [])

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

      Logger.warning(
        "[OAuth] strategy.callback result keys=#{inspect(Map.keys(result))}, " <>
          "user_data=#{inspect(user_data)}, type=#{inspect(is_map(user_data))}"
      )

      case provider_mod.normalize_user(user_data) do
        {:ok, normalized} ->
          {:ok, %{token: token, normalized: normalized}}

        {:error, reason} = err ->
          Logger.warning(
            "[OAuth] normalize_user failed: #{inspect(reason)}, user_data=#{inspect(user_data)}"
          )

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
  Returns the integration with a fresh token. If the token is not expired,
  returns it as-is. If expired and a refresh token is available, refreshes it.
  Returns `{:error, :token_expired}` if the token is expired and cannot be refreshed.
  """
  @spec ensure_fresh_token(Scope.t(), Integration.t()) ::
          {:ok, Integration.t()} | {:error, :token_expired}
  def ensure_fresh_token(%Scope{} = scope, %Integration{} = integration) do
    cond do
      not Integration.expired?(integration) ->
        {:ok, integration}

      Integration.has_refresh_token?(integration) ->
        case refresh_token(scope, integration) do
          {:ok, refreshed} -> {:ok, refreshed}
          {:error, _reason} -> {:error, :token_expired}
        end

      true ->
        {:error, :token_expired}
    end
  end

  @google_family_providers [
    :google_ads,
    :google_analytics,
    :google_search_console,
    :google_business
  ]

  @doc """
  Connects `target_provider` by reusing an existing Google-family
  integration's token, instead of a fresh OAuth authorization.

  `google_ads`, `google_analytics`, `google_search_console` and
  `google_business` are all authorized under the same Google OAuth app and
  consent screen, so a user who already granted access via one of them does
  not need to grant it again for another -- Google issues one token per
  app-user pair, not one per MetricFlow provider.

  Returns `{:error, :no_existing_google_token}` when no other usable
  Google-family integration exists, so the caller can fall back to a fresh
  OAuth authorization.
  """
  @spec reuse_google_token(Scope.t(), atom()) ::
          {:ok, Integration.t()} | {:error, :no_existing_google_token | Ecto.Changeset.t()}
  def reuse_google_token(%Scope{} = scope, target_provider)
      when target_provider in @google_family_providers do
    case find_reusable_google_integration(scope, target_provider) do
      nil ->
        {:error, :no_existing_google_token}

      source ->
        attrs = %{
          access_token: source.access_token,
          refresh_token: source.refresh_token,
          expires_at: source.expires_at,
          granted_scopes: source.granted_scopes
        }

        IntegrationRepository.upsert_integration(scope, target_provider, attrs)
    end
  end

  defp find_reusable_google_integration(scope, target_provider) do
    required_scopes = required_api_scopes(target_provider)

    scope
    |> list_integrations()
    |> Enum.find(fn integration ->
      integration.provider in @google_family_providers and
        integration.provider != target_provider and
        (not Integration.expired?(integration) or Integration.has_refresh_token?(integration)) and
        required_scopes != [] and
        Enum.all?(required_scopes, &(&1 in (integration.granted_scopes || [])))
    end)
  end

  # Each Google-family provider is authorized under its own distinct API
  # scope (adwords, analytics.readonly, webmasters.readonly, business.manage)
  # -- Google only grants API access to scopes actually consented to, so a
  # token is only safely reusable for another provider when it already
  # carries that provider's required scope.
  defp required_api_scopes(target_provider) do
    case fetch_provider(target_provider) do
      {:ok, mod} ->
        mod.config()
        |> Keyword.get(:authorization_params, [])
        |> Keyword.get(:scope, "")
        |> parse_scopes()
        |> Enum.filter(&String.starts_with?(&1, "https://"))

      {:error, _} ->
        []
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
  defp token_url_for(:google_business), do: "https://oauth2.googleapis.com/token"
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
    with {:ok, integration} <-
           IntegrationRepository.get_integration(scope, :google_search_console) do
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
  Lists all locations across configured Google Business Profile accounts.

  Reads `google_business_account_ids` from the integration's provider_metadata
  and fetches locations for each, handling pagination automatically.
  """
  @spec list_google_business_locations(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_business_locations(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :google_business),
         {:ok, fresh} <- ensure_fresh_integration(scope, integration) do
      GoogleBusinessLocations.list_locations(fresh, opts)
    end
  end

  @doc """
  Lists the GBP *accounts* (not locations) the scoped user's Google token has
  access to -- the step that must come before a location can be selected,
  since a location always belongs to one of these accounts.
  """
  @spec list_google_business_accounts(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_business_accounts(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- IntegrationRepository.get_integration(scope, :google_business),
         {:ok, fresh} <- ensure_fresh_integration(scope, integration) do
      GoogleBusinessLocations.list_accounts(fresh, opts)
    end
  end

  # Refreshes the token if expired, returns the integration as-is if still valid.
  defp ensure_fresh_integration(scope, %Integration{} = integration) do
    if Integration.expired?(integration) and is_binary(integration.refresh_token) do
      refresh_token(scope, integration)
    else
      {:ok, integration}
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
  def update_provider_metadata(%Scope{} = scope, provider, new_metadata)
      when is_map(new_metadata) do
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
    |> with_static_discovery(provider_mod.strategy())
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
  defp maybe_preserve_provider_metadata(%{provider_metadata: meta} = attrs, %{
         provider_metadata: existing
       })
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
