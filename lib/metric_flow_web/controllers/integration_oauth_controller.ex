defmodule MetricFlowWeb.IntegrationOauthController do
  @moduledoc """
  Handles OAuth provider integration flows.

  ## Request Phase
  - User clicks "Connect" button on a platform card
  - `request/2` generates authorization URL and stores session params
    in a server-side ETS store keyed by the state token
  - User is redirected to provider for consent

  ## Callback Phase
  - Provider redirects back with authorization code and state
  - `callback/2` retrieves session params from ETS using the state token
  - Integration is created/updated with encrypted credentials
  - User is redirected to integrations page

  Session params are stored server-side (not in cookies or the Phoenix
  session) because reverse proxies can strip Set-Cookie headers from 302
  redirect responses, causing CSRF state verification to fail.
  """

  use MetricFlowWeb, :controller

  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.OAuthStateStore

  require Logger

  plug :pin_requested_account when action in [:request]

  @google_product_strs Enum.map(Integrations.google_products(), &Atom.to_string/1)

  # A connect link from an agent names the account it is for
  # (`Onboarding.connect_path/3`), so the connection lands there rather than
  # on whichever account happens to be active in this browser.
  defp pin_requested_account(%{params: %{"account_id" => raw}} = conn, _opts) do
    scope = conn.assigns.current_scope

    with {id, ""} <- Integer.parse(to_string(raw)),
         true <- MetricFlow.AccountAccess.member?(scope.user.id, id) do
      assign(conn, :current_scope, MetricFlow.Users.Scope.put_account_id(scope, id))
    else
      _ ->
        conn
        |> put_flash(:error, "You don't have access to the account this link is for.")
        |> redirect(to: ~p"/app/onboarding/connect")
        |> halt()
    end
  end

  defp pin_requested_account(conn, _opts), do: conn

  @doc """
  Initiates OAuth flow by redirecting to provider authorization URL.

  Session params from Assent are stored in a server-side ETS table keyed
  by the state value. The provider echoes the state back in the callback,
  allowing retrieval without cookies.
  """
  def request(conn, %{"provider" => "youtube"} = request_params) do
    scope = youtube_scope(conn)

    with :ok <- Integrations.authorize_youtube_connection(scope),
         {:ok, %{url: url, session_params: params}} <- Integrations.authorize_url(:youtube),
         state when is_binary(state) <- params[:state] || params["state"] do
      bound_params =
        params
        |> Map.merge(%{youtube_user_id: scope.user.id, youtube_account_id: scope.account_id})
        |> put_return_to(request_params)

      OAuthStateStore.store(state, bound_params)
      Logger.info("YouTube authorize redirect: #{redact_authorize_url(url)}")
      redirect(conn, external: url)
    else
      _ ->
        conn
        |> put_flash(
          :error,
          "YouTube could not be connected. Check your account access and try again."
        )
        |> redirect(to: ~p"/app/integrations/connect")
    end
  end

  # One consent for every Google product (Analytics, Ads, Search Console,
  # Business Profile). See `Integrations.google_bundle_authorize_url/0`.
  def request(conn, %{"provider" => "google_bundle"} = params) do
    case Integrations.google_bundle_authorize_url() do
      {:ok, %{url: url, session_params: session_params}} ->
        state = Map.get(session_params, :state) || Map.get(session_params, "state")

        OAuthStateStore.store(
          state,
          session_params |> put_return_to(params) |> put_account(conn)
        )

        redirect(conn, external: url)

      {:error, reason} ->
        Logger.error("Failed to generate Google bundle OAuth URL: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Couldn't start the Google connection. Please try again.")
        |> redirect(to: safe_return_to(params["return_to"]) || ~p"/app/onboarding/connect")
    end
  end

  # Google products have no sign-in of their own: they all ride the one
  # Google consent, landing back on the product's page by default.
  def request(conn, %{"provider" => provider_str} = params)
      when provider_str in ["google" | @google_product_strs] do
    return_to =
      safe_return_to(params["return_to"]) ||
        if provider_str == "google",
          do: "/app/onboarding/connect?step=google",
          else: "/app/integrations/connect/#{provider_str}"

    request(conn, %{params | "provider" => "google_bundle"} |> Map.put("return_to", return_to))
  end

  def request(conn, %{"provider" => provider_str} = params) do
    provider = String.to_existing_atom(provider_str)

    case Integrations.authorize_url(provider) do
      {:ok, %{url: url, session_params: session_params}} ->
        session_params = session_params |> put_return_to(params) |> put_account(conn)
        state = Map.get(session_params, :state) || Map.get(session_params, "state")

        if state do
          OAuthStateStore.store(state, session_params)
          Logger.debug("OAuth request — stored state=#{state} for provider=#{provider}")
        else
          Logger.warning(
            "OAuth request — no state in session_params (keys: #{inspect(Map.keys(session_params))})"
          )
        end

        redirect(conn, external: url)

      # `integration_oauth_controller.spec.md` lists "unsupported provider" and
      # "authorize_url fails" as separate cases, so they need separate messages.
      # This used to be distinguished by `String.to_existing_atom/1` raising —
      # which it does not: atoms are never collected, so once anything in the
      # system has mentioned `:nonexistent_provider` the lookup succeeds and the
      # rescue below is unreachable. `Integrations.authorize_url/1` answers
      # `{:error, :unsupported_provider}` (integrations.spec.md:57), which is a
      # fact about the provider rather than about the atom table.
      {:error, :unsupported_provider} ->
        unsupported(conn)

      {:error, reason} ->
        Logger.error("Failed to generate OAuth URL for #{provider}: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to connect to #{provider_str}")
        |> redirect(to: ~p"/app/integrations/connect")
    end
  rescue
    # Still reachable for a provider string no code has ever named.
    ArgumentError -> unsupported(conn)
  end

  defp unsupported(conn) do
    conn
    |> put_flash(:error, "This platform is not yet supported")
    |> redirect(to: ~p"/app/integrations/connect")
  end

  @doc """
  Handles OAuth callback from provider.

  Reads provider from the URL path parameter and retrieves session params
  from the server-side ETS store using the state token echoed back by the
  provider.
  """
  def callback(conn, %{"provider" => "youtube"} = params) do
    scope = youtube_scope(conn)
    session_params = fetch_session_params(params)

    result =
      if params["error"] do
        {:error, :consent_denied}
      else
        Integrations.prepare_youtube_connection(scope, session_params, params)
      end

    case result do
      {:ok, token} ->
        conn
        |> put_session(:youtube_pending_authorization, token)
        |> put_session(:youtube_return_to, return_to_from(session_params))
        |> redirect(to: ~p"/app/integrations/connect/youtube/accounts")

      {:error, reason} ->
        Logger.warning(
          "YouTube callback failed: reason=#{inspect(reason)} google_error=#{inspect(params["error"])}"
        )

        message =
          case reason do
            :consent_denied ->
              "YouTube was not connected because consent was cancelled or denied."

            :no_youtube_channels ->
              "No YouTube channels were found for this Google account."

            _ ->
              "YouTube could not be connected. Please try again and grant channel and analytics access."
          end

        conn
        |> delete_session(:youtube_pending_authorization)
        |> put_flash(:error, message)
        |> redirect(to: ~p"/app/integrations/connect/youtube")
    end
  end

  def callback(conn, %{"provider" => provider_str} = params) do
    session_params = fetch_session_params(params)

    # Every Google product connects through the one Google consent.
    if Map.get(session_params, :google_bundle) || Map.get(session_params, "google_bundle") ||
         provider_str in @google_product_strs,
       do: google_bundle_callback(conn, provider_str, params, session_params),
       else: provider_callback(conn, provider_str, params, session_params)
  end

  defp google_bundle_callback(conn, provider_str, params, session_params) do
    return_to =
      return_to_from(session_params) ||
        if provider_str in @google_product_strs,
          do: "/app/integrations/connect/#{provider_str}",
          else: ~p"/app/onboarding/connect"

    result =
      if params["error"],
        do: {:error, params["error"]},
        else:
          Integrations.handle_google_bundle_callback(
            callback_scope(conn, session_params),
            session_params,
            params
          )

    case result do
      {:ok, %{connected: []}} ->
        conn
        |> put_flash(
          :error,
          "Google connected, but no data access was granted. Tick at least one product on Google's screen."
        )
        |> redirect(to: return_to)

      {:ok, %{connected: connected}} ->
        conn
        |> put_flash(:info, bundle_success_message(return_to, connected))
        |> redirect(to: return_to)

      {:error, reason} ->
        Logger.error("Google bundle OAuth callback failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, format_oauth_error(params, :google, reason))
        |> redirect(to: return_to)
    end
  end

  defp provider_callback(conn, provider_str, params, session_params) do
    scope = callback_scope(conn, session_params)
    provider = parse_provider(provider_str)

    redirect_to =
      cond do
        provider == :codemyspec -> ~p"/app/users/settings"
        rt = return_to_from(session_params) -> rt
        true -> ~p"/app/integrations/connect/#{provider_str}"
      end

    case handle_oauth_callback(scope, provider, params, session_params) do
      {:ok, _integration} ->
        conn
        |> put_flash(:info, "Successfully connected!")
        |> redirect(to: redirect_to)

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to persist integration: #{inspect(changeset.errors)}")

        conn
        |> put_flash(:error, "Failed to save integration")
        |> redirect(to: ~p"/app/integrations/connect/#{provider_str}")

      {:error, reason} ->
        Logger.error("OAuth callback failed for #{provider_str}: #{inspect(reason)}")

        error_message = format_oauth_error(params, provider, reason)

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: ~p"/app/integrations/connect/#{provider_str}")
    end
  rescue
    e in [KeyError, ArgumentError] ->
      Logger.error("OAuth callback crashed for #{provider_str}: #{Exception.message(e)}")

      conn
      |> put_flash(:error, "Could not complete the connection. Please try again.")
      |> redirect(to: ~p"/app/integrations/connect/#{provider_str}")
  end

  # Private Helpers

  # The authorize URL minus the per-user bits, for diagnosing what Google got.
  defp redact_authorize_url(url) do
    uri = URI.parse(url)

    query =
      (uri.query || "")
      |> URI.decode_query()
      |> Map.drop(["state", "client_id", "nonce"])

    "#{uri.host}#{uri.path} #{inspect(query)}"
  end

  # A single product's connect page shows its "connected" result state for
  # exactly this message.
  defp bundle_success_message("/app/integrations/connect/" <> _, _connected),
    do: "Successfully connected!"

  defp bundle_success_message(_return_to, connected),
    do: "Google connected — #{length(connected)} product(s) ready to set up."

  # `return_to` lets the setup wizard (or an agent's connect link) bring the
  # user back where they started. Only in-app paths are honoured.
  defp put_return_to(session_params, params) do
    case safe_return_to(params["return_to"]) do
      nil -> session_params
      path -> Map.put(session_params, :return_to, path)
    end
  end

  defp return_to_from(session_params),
    do:
      safe_return_to(Map.get(session_params, :return_to) || Map.get(session_params, "return_to"))

  defp safe_return_to("/app/" <> rest = path) when is_binary(rest) do
    if String.contains?(path, ["//", "\\", "\n", "\r"]), do: nil, else: path
  end

  defp safe_return_to(_), do: nil

  defp youtube_scope(conn), do: active_scope(conn)

  # Connections belong to the active account -- the same one the account
  # switcher shows (see MetricFlowWeb.Hooks.ActiveAccountHook).
  defp active_scope(conn) do
    MetricFlowWeb.Hooks.ActiveAccountHook.put_active_account(conn.assigns.current_scope)
  end

  # The callback lands on the account that was active when the user clicked
  # Connect (pinned in the server-side state), so switching accounts in
  # another tab mid-consent cannot redirect the connection. Membership is
  # re-checked by every account-scoped query.
  defp callback_scope(conn, session_params) do
    case Map.get(session_params, :account_id) || Map.get(session_params, "account_id") do
      account_id when is_integer(account_id) ->
        MetricFlow.Users.Scope.put_account_id(conn.assigns.current_scope, account_id)

      _ ->
        active_scope(conn)
    end
  end

  defp put_account(session_params, conn) do
    case active_scope(conn) do
      %{account_id: account_id} when is_integer(account_id) ->
        Map.put(session_params, :account_id, account_id)

      _ ->
        session_params
    end
  end

  @callback_provider_map %{
    "google" => :google,
    "facebook_ads" => :facebook_ads,
    "quickbooks" => :quickbooks,
    "google_business_reviews" => :google_business_reviews,
    "codemyspec" => :codemyspec
  }

  defp parse_provider(provider_str), do: Map.get(@callback_provider_map, provider_str)

  defp fetch_session_params(%{"state" => state}) when is_binary(state) do
    case OAuthStateStore.fetch(state) do
      {:ok, session_params} ->
        session_params

      :error ->
        Logger.warning("OAuth state not found in store for state=#{state}")
        %{}
    end
  end

  defp fetch_session_params(_params) do
    Logger.warning("No state parameter in OAuth callback")
    %{}
  end

  defp handle_oauth_callback(_scope, nil, _params, _session_params) do
    {:error, :unsupported_provider}
  end

  defp handle_oauth_callback(scope, provider, params, session_params) do
    case Map.get(params, "error") do
      nil ->
        Integrations.handle_callback(scope, provider, session_params, params)

      error ->
        {:error, error}
    end
  end

  defp format_oauth_error(
         %{"error" => error, "error_description" => description},
         _provider,
         _reason
       )
       when is_binary(description) and description != "" do
    Logger.info("OAuth callback error=#{error} error_description=#{description}")
    "Authorization failed: #{description}"
  end

  defp format_oauth_error(%{"error" => "access_denied"}, _provider, _reason) do
    "Access was denied. Please try again if you want to connect."
  end

  defp format_oauth_error(%{"error" => error}, _provider, _reason) do
    "Authorization failed: #{error}"
  end

  defp format_oauth_error(_params, nil, :unsupported_provider) do
    "This platform is not yet supported."
  end

  defp format_oauth_error(_params, _provider, :unsupported_provider) do
    "Could not complete the connection. Please try again."
  end

  defp format_oauth_error(_params, _provider, :unauthorized) do
    "Only account owners, admins and account managers can connect data sources."
  end

  defp format_oauth_error(_params, _provider, _reason) do
    "Could not complete the connection. Please try again."
  end
end
