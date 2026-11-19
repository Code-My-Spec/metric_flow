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
  alias MetricFlow.AccountAccess
  alias MetricFlow.Integrations.FacebookAdsAccounts
  alias MetricFlow.Integrations.GoogleAccounts
  alias MetricFlow.Integrations.GoogleAdsAccounts
  alias MetricFlow.Integrations.GoogleBusinessLocations
  alias MetricFlow.Integrations.GoogleSearchConsoleSites
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Integrations.IntegrationNotifier
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

  defdelegate list_integrations(scope), to: IntegrationRepository
  defdelegate list_all_active_integrations(), to: IntegrationRepository
  defdelegate delete_integration(scope, provider), to: IntegrationRepository
  defdelegate delete_all_integrations(scope), to: IntegrationRepository
  defdelegate get_integration_by_id(id), to: IntegrationRepository
  defdelegate update_integration(scope, provider, attrs), to: IntegrationRepository
  defdelegate authorize_write(scope, provider), to: IntegrationRepository

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

  @doc """
  Emails the account's owners and admins that `integration` must be
  reconnected, then stamps `reconnection_notified_at` so they are told once
  per expiry. Runs as housekeeping on the account (any member's page view may
  trigger it), not as the viewing member.
  """
  @spec notify_reconnection_required(Integration.t(), String.t()) ::
          {:ok, Integration.t()} | {:error, term()}
  def notify_reconnection_required(
        %Integration{account_id: account_id} = integration,
        provider_name
      )
      when is_integer(account_id) do
    account_id
    |> AccountAccess.admin_emails()
    |> Enum.each(&IntegrationNotifier.deliver_reconnection_required(&1, provider_name))

    put_reconnection_notified_at(integration, DateTime.utc_now())
  end

  @doc "Sets or clears `reconnection_notified_at` on an account's integration."
  @spec put_reconnection_notified_at(Integration.t(), DateTime.t() | nil) ::
          {:ok, Integration.t()} | {:error, term()}
  def put_reconnection_notified_at(%Integration{account_id: account_id} = integration, value)
      when is_integer(account_id) do
    IntegrationRepository.update_integration(
      Scope.for_account(account_id),
      integration.provider,
      %{reconnection_notified_at: value}
    )
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
  # One Google integration for every Google product
  # ---------------------------------------------------------------------------

  # Google products live on the account's single `:google` integration: one
  # token, one row. Each product needs its API scope(s) granted and its
  # selection saved under its own provider_metadata key(s) — the keys don't
  # collide, so one row holds every product's selection. `clear` lists the
  # keys dropped when that one product is disconnected.
  @google_products [
    google_analytics: %{
      scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
      selection_key: "property_id",
      clear: ["property_id"]
    },
    google_ads: %{
      scopes: ["https://www.googleapis.com/auth/adwords"],
      selection_key: "customer_id",
      clear: ["customer_id", "login_customer_id"]
    },
    google_search_console: %{
      scopes: ["https://www.googleapis.com/auth/webmasters.readonly"],
      selection_key: "site_url",
      clear: ["site_url"]
    },
    google_business: %{
      scopes: ["https://www.googleapis.com/auth/business.manage"],
      selection_key: "included_locations",
      clear: ["included_locations"]
    }
  ]

  @doc "The Google products held by the account's `:google` integration."
  @spec google_products() :: [atom()]
  def google_products, do: Keyword.keys(@google_products)

  @doc "True for a Google product (`:google_analytics`, `:google_ads`, …)."
  @spec google_product?(term()) :: boolean()
  def google_product?(product), do: Keyword.has_key?(@google_products, product)

  @doc "The Google API scopes each Google product needs, keyed by product provider."
  @spec google_product_scopes() :: %{atom() => [String.t()]}
  def google_product_scopes, do: Map.new(@google_products, fn {k, v} -> {k, v.scopes} end)

  @doc """
  The integration provider that holds `product`: `:google` for every Google
  product, otherwise the product itself.
  """
  @spec integration_provider(atom()) :: atom()
  def integration_provider(product) do
    if google_product?(product), do: :google, else: product
  end

  @doc """
  The data products `integrations` connect: the `:google` integration
  expands to the Google products its grant covers; any other integration is
  its own product.
  """
  @spec connected_products([Integration.t()]) :: [atom()]
  def connected_products(integrations) do
    Enum.flat_map(integrations, fn
      %Integration{provider: :google} = google ->
        Enum.filter(google_products(), &product_granted?(google, &1))

      %Integration{provider: provider} ->
        [provider]
    end)
  end

  @doc "True when `integration`'s grant covers every scope `product` needs."
  @spec product_granted?(Integration.t(), atom()) :: boolean()
  def product_granted?(%Integration{granted_scopes: granted}, product) do
    case Keyword.fetch(@google_products, product) do
      {:ok, %{scopes: scopes}} -> Enum.all?(scopes, &(&1 in (granted || [])))
      :error -> true
    end
  end

  @doc "True when `product` has a selection saved on `integration`."
  @spec product_selected?(Integration.t(), atom()) :: boolean()
  def product_selected?(%Integration{provider_metadata: meta}, product) do
    case Keyword.fetch(@google_products, product) do
      {:ok, %{selection_key: key}} -> List.wrap((meta || %{})[key]) not in [[], [""], [nil]]
      :error -> false
    end
  end

  @doc """
  Disconnects one Google product: clears its selection from the account's
  `:google` integration so it stops syncing. The Google sign-in (and every
  other product) stays connected.
  """
  @spec clear_product_selection(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, term()}
  def clear_product_selection(%Scope{} = scope, product) do
    with {:ok, %{clear: keys}} <- Keyword.fetch(@google_products, product) |> ok_or_unknown(),
         {:ok, integration} <- get_integration(scope, product) do
      IntegrationRepository.update_integration(scope, :google, %{
        provider_metadata: Map.drop(integration.provider_metadata || %{}, keys)
      })
    end
  end

  defp ok_or_unknown({:ok, _} = ok), do: ok
  defp ok_or_unknown(:error), do: {:error, :unknown_product}

  @doc """
  The account's integration for `provider`. A Google product resolves to the
  account's single `:google` integration.
  """
  @spec get_integration(Scope.t(), atom()) :: {:ok, Integration.t()} | {:error, :not_found}
  def get_integration(%Scope{} = scope, provider),
    do: IntegrationRepository.get_integration(scope, integration_provider(provider))

  @doc """
  True when the account has `provider` connected. A Google product counts as
  connected when the account's `:google` integration grants its scope.
  """
  @spec connected?(Scope.t(), atom()) :: boolean()
  def connected?(%Scope{} = scope, provider) do
    case get_integration(scope, provider) do
      {:ok, integration} -> product_granted?(integration, provider)
      {:error, _} -> false
    end
  end

  @doc """
  Builds one Google consent URL covering every Google product.

  The flow rides the Google Analytics provider's OAuth client and redirect
  URI (already registered with Google), asks for every product scope at once,
  and sets `include_granted_scopes` so the grant merges with anything the
  user consented to before. Google shows per-scope checkboxes, so the user
  may grant only some products; the `:google` integration records exactly
  the scopes granted.

  The returned `session_params` carry `google_bundle: true`, which is how
  the callback tells this flow apart from a plain Google Analytics connect.
  """
  @spec google_bundle_authorize_url() ::
          {:ok, %{url: String.t(), session_params: map()}} | {:error, term()}
  def google_bundle_authorize_url do
    with {:ok, mod} <- fetch_provider(:google_analytics) do
      scope =
        (["openid", "email", "profile"] ++ Enum.flat_map(@google_products, &elem(&1, 1).scopes))
        |> Enum.join(" ")

      config =
        mod.config()
        |> Keyword.update(:authorization_params, [], fn params ->
          params
          |> Keyword.put(:scope, scope)
          |> Keyword.put(:include_granted_scopes, "true")
        end)
        |> with_static_discovery(mod.strategy())

      with {:ok, %{session_params: params} = result} <- mod.strategy().authorize_url(config) do
        {:ok, %{result | session_params: Map.put(params, :google_bundle, true)}}
      end
    end
  end

  @doc """
  Completes the single Google grant: exchanges the code once and upserts the
  account's one `:google` integration with the token and the scopes granted.
  Selections already saved survive (provider_metadata is merged).

  Returns `{:ok, %{connected: [product], not_granted: [product]}}`.
  """
  @spec handle_google_bundle_callback(Scope.t(), map(), map()) ::
          {:ok, %{connected: [atom()], not_granted: [atom()]}} | {:error, term()}
  def handle_google_bundle_callback(%Scope{} = scope, session_params, callback_params) do
    with :ok <- require_state(session_params),
         {:ok, mod} <- fetch_provider(:google_analytics),
         config = build_callback_config(mod, session_params),
         {:ok, result} <- exchange_and_normalize(mod.strategy(), config, callback_params, mod),
         attrs = build_integration_attrs(result.token, result.normalized),
         {:ok, integration} <- IntegrationRepository.upsert_integration(scope, :google, attrs) do
      {connected, not_granted} =
        Enum.split_with(google_products(), &product_granted?(integration, &1))

      {:ok, %{connected: Enum.sort(connected), not_granted: Enum.sort(not_granted)}}
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
         :ok <- youtube_session_matches(scope, session_params),
         {:ok, provider_mod} <- fetch_provider(:youtube),
         config = build_callback_config(provider_mod, session_params),
         {:ok, result} <-
           exchange_and_normalize(provider_mod.strategy(), config, callback_params, provider_mod),
         attrs = build_integration_attrs(result.token, result.normalized),
         :ok <- require_youtube_scopes(attrs.granted_scopes),
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
    end
  end

  # A callback whose state was already used (reload, back button, an old
  # Google tab) has no session params bound to this user and account.
  defp youtube_session_matches(scope, session_params) do
    if session_params[:youtube_user_id] == scope.user.id and
         session_params[:youtube_account_id] == scope.account_id,
       do: :ok,
       else: {:error, :youtube_session_mismatch}
  end

  defp require_youtube_scopes(granted) do
    if youtube_scopes_granted?(granted), do: :ok, else: {:error, :youtube_scopes_not_granted}
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
          "user_data_keys=#{inspect(if is_map(user_data), do: Map.keys(user_data), else: nil)}"
      )

      case provider_mod.normalize_user(user_data) do
        {:ok, normalized} ->
          {:ok, %{token: token, normalized: normalized}}

        {:error, reason} = err ->
          Logger.warning("[OAuth] normalize_user failed: #{inspect(reason)}")

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

          # A token refresh is housekeeping, not a member's change, so any
          # member's read (or a background sync) may trigger it.
          IntegrationRepository.update_integration(
            refresh_scope(scope, integration),
            integration.provider,
            attrs
          )

        {:error, reason} ->
          {:error, reason}
      end
    end
  rescue
    e ->
      Logger.warning("Token refresh raised for #{integration.provider}: #{Exception.message(e)}")

      {:error, :token_refresh_failed}
  end

  defp refresh_scope(scope, %Integration{account_id: account_id}) when is_integer(account_id) do
    if AccountAccess.account_id(scope) == account_id,
      do: Scope.for_account(account_id),
      else: scope
  end

  defp refresh_scope(scope, _integration), do: scope

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
  defp token_url_for(:facebook_ads), do: "https://graph.facebook.com/v21.0/oauth/access_token"
  defp token_url_for(:quickbooks), do: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
  defp token_url_for(_), do: "/oauth/token"

  # ---------------------------------------------------------------------------
  # Google account listing
  # ---------------------------------------------------------------------------

  @doc """
  Lists GA4 properties accessible to the user's Google integration.

  Fetches the account's `:google` integration, then queries the Google
  Analytics Admin API for available properties. Returns `{:error, :not_found}`
  when no Google integration exists.

  ## Options

    * `:http_plug` - A Plug-compatible function for test injection.
  """
  @spec list_google_accounts(Scope.t(), atom(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_accounts(%Scope{} = scope, provider \\ :google_analytics, opts \\ []) do
    with {:ok, integration} <- get_integration(scope, provider) do
      GoogleAccounts.list_ga4_properties(integration, opts)
    end
  end

  @doc """
  Lists Google Ads customer accounts accessible to the user's Google Ads integration.
  """
  @spec list_google_ads_customers(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_google_ads_customers(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- get_integration(scope, :google_ads) do
      GoogleAdsAccounts.list_customers(integration, opts)
    end
  end

  @doc """
  Lists verified sites accessible to the user's Google Search Console integration.
  """
  @spec list_search_console_sites(Scope.t(), keyword()) ::
          {:ok, list(map())} | {:error, term()}
  def list_search_console_sites(%Scope{} = scope, opts \\ []) do
    with {:ok, integration} <- get_integration(scope, :google_search_console) do
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
    with {:ok, integration} <- get_integration(scope, :google_business),
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
    with {:ok, integration} <- get_integration(scope, :google_business),
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
    with {:ok, integration} <- get_integration(scope, provider) do
      merged = Map.merge(integration.provider_metadata || %{}, new_metadata)

      IntegrationRepository.update_integration(scope, integration.provider, %{
        provider_metadata: merged
      })
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
