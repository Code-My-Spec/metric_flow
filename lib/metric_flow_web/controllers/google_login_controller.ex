defmodule MetricFlowWeb.GoogleLoginController do
  @moduledoc """
  "Continue with Google" sign-in / sign-up.

  Identity scopes only. Session params are kept in `OAuthStateStore` (keyed by
  the state token) rather than the cookie session, for the same reverse-proxy
  reason as `IntegrationOauthController`. Connecting Analytics/Ads stays a
  separate flow under `/app/integrations`.
  """

  use MetricFlowWeb, :controller

  alias MetricFlow.Accounts
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.OAuthStateStore
  alias MetricFlow.Users
  alias MetricFlow.Users.Scope
  alias MetricFlowWeb.UserAuth

  require Logger

  def login(conn, params) do
    with {:ok, %{url: url, session_params: session_params}} <- Integrations.authorize_login_url(),
         state when is_binary(state) <- session_params[:state] || session_params["state"] do
      OAuthStateStore.store(state, session_params)

      conn
      |> put_return_to(params["return_to"])
      |> redirect(external: url)
    else
      error ->
        Logger.error("Google login: could not build authorization URL: #{inspect(error)}")
        failed(conn, "Unable to reach Google. Please try again.")
    end
  end

  def callback(conn, %{"error" => error}) do
    Logger.info("Google login denied/failed: #{inspect(error)}")
    failed(conn, "Google sign-in was cancelled.")
  end

  def callback(conn, %{"state" => state} = params) when is_binary(state) do
    with {:ok, session_params} <- OAuthStateStore.fetch(state),
         {:ok, profile} <- Integrations.handle_login_callback(session_params, params),
         {:ok, user, status} <- Users.find_or_register_oauth_user(profile) do
      if status == :new, do: create_account(user)

      UserAuth.log_in_user(
        put_flash(conn, :info, "Welcome#{if status == :new, do: "", else: " back"}!"),
        user,
        %{"remember_me" => "true"}
      )
    else
      {:error, :email_not_verified} ->
        failed(conn, "Your Google email address is not verified.")

      {:error, reason} ->
        Logger.warning("Google login failed: #{inspect(reason)}")
        failed(conn, "Google sign-in failed. Please try again.")

      :error ->
        failed(conn, "That sign-in link expired. Please try again.")
    end
  end

  def callback(conn, _params), do: failed(conn, "Google sign-in failed. Please try again.")

  defp failed(conn, message) do
    conn |> put_flash(:error, message) |> redirect(to: ~p"/users/log-in")
  end

  defp create_account(user) do
    slug =
      "#{user.account_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")}-#{:erlang.unique_integer([:positive])}"

    Accounts.create_team_account(
      Scope.for_user(user),
      %{name: user.account_name, slug: slug},
      :client
    )
  end

  # Local paths only (no `//host`) — otherwise this is an open redirect.
  defp put_return_to(conn, "/" <> rest = path) when rest != "" do
    if String.starts_with?(rest, "/"), do: conn, else: put_session(conn, :user_return_to, path)
  end

  defp put_return_to(conn, _), do: conn
end
