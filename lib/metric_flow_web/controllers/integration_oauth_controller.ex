defmodule MetricFlowWeb.IntegrationOAuthController do
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

  @doc """
  Initiates OAuth flow by redirecting to provider authorization URL.

  Session params from Assent are stored in a server-side ETS table keyed
  by the state value. The provider echoes the state back in the callback,
  allowing retrieval without cookies.
  """
  def request(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)

    case Integrations.authorize_url(provider) do
      {:ok, %{url: url, session_params: session_params}} ->
        state = Map.get(session_params, :state) || Map.get(session_params, "state")

        if state do
          OAuthStateStore.store(state, session_params)
          Logger.debug("OAuth request — stored state=#{state} for provider=#{provider}")
        else
          Logger.warning("OAuth request — no state in session_params: #{inspect(session_params)}")
        end

        redirect(conn, external: url)

      {:error, reason} ->
        Logger.error("Failed to generate OAuth URL for #{provider}: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to connect to #{provider_str}")
        |> redirect(to: ~p"/integrations/connect")
    end
  rescue
    ArgumentError ->
      conn
      |> put_flash(:error, "This platform is not yet supported")
      |> redirect(to: ~p"/integrations/connect")
  end

  @doc """
  Handles OAuth callback from provider.

  Reads provider from the URL path parameter and retrieves session params
  from the server-side ETS store using the state token echoed back by the
  provider.
  """
  def callback(conn, %{"provider" => provider_str} = params) do
    scope = conn.assigns.current_scope
    session_params = fetch_session_params(params)

    provider =
      case provider_str do
        "google" -> :google
        "google_ads" -> :google_ads
        "google_analytics" -> :google_analytics
        "facebook_ads" -> :facebook_ads
        "quickbooks" -> :quickbooks
        "google_search_console" -> :google_search_console
        "google_business" -> :google_business
        "google_business_reviews" -> :google_business_reviews
        "codemyspec" -> :codemyspec
        _ -> nil
      end

    redirect_to = if provider == :codemyspec, do: ~p"/users/settings", else: ~p"/integrations/connect/#{provider_str}"

    case handle_oauth_callback(scope, provider, params, session_params) do
      {:ok, _integration} ->
        conn
        |> put_flash(:info, "Successfully connected!")
        |> redirect(to: redirect_to)

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed to persist integration: #{inspect(changeset)}")

        conn
        |> put_flash(:error, "Failed to save integration")
        |> redirect(to: ~p"/integrations/connect/#{provider_str}")

      {:error, reason} ->
        Logger.error("OAuth callback failed for #{provider_str}: #{inspect(reason)}")

        error_message = format_oauth_error(params, provider, reason)

        conn
        |> put_flash(:error, error_message)
        |> redirect(to: ~p"/integrations/connect/#{provider_str}")
    end
  rescue
    e in [KeyError, ArgumentError] ->
      Logger.error("OAuth callback crashed for #{provider_str}: #{Exception.message(e)}")

      conn
      |> put_flash(:error, "Could not complete the connection. Please try again.")
      |> redirect(to: ~p"/integrations/connect/#{provider_str}")
  end

  # Private Helpers

  defp fetch_session_params(%{"state" => state}) when is_binary(state) do
    case OAuthStateStore.fetch(state) do
      {:ok, session_params} -> session_params
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

  defp format_oauth_error(%{"error" => "access_denied"}, _provider, _reason) do
    "Access was denied. Please try again if you want to connect."
  end

  defp format_oauth_error(%{"error" => error, "error_description" => description}, _provider, _reason) do
    "Authorization failed: #{description} (#{error})"
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

  defp format_oauth_error(_params, _provider, _reason) do
    "Could not complete the connection. Please try again."
  end
end
