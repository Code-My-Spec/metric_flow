defmodule MetricFlowWeb.IntegrationLive.ConnectTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Stub providers
  #
  # OAuth calls leave the application boundary — we substitute stub provider
  # modules so tests remain fast and deterministic without real OAuth credentials
  # or network access. The pattern mirrors the one used in integrations_test.exs.
  #
  # Application.put_env is used in setup so individual tests can override the
  # map when needed.
  # ---------------------------------------------------------------------------

  defmodule StubStrategy do
    @moduledoc false

    @state "liveview-csrf-state-token"
    @auth_url "https://stub.example.com/oauth/authorize?response_type=code&state=#{@state}"

    def authorize_url(_config) do
      {:ok, %{url: @auth_url, session_params: %{state: @state}}}
    end

    def callback(_config, _params) do
      {:ok,
       %{
         token: %{
           "access_token" => "stub-access-token",
           "refresh_token" => "stub-refresh-token",
           "expires_in" => 3600,
           "scope" => "email profile"
         },
         user: %{"sub" => "stub-user-id", "email" => "stub@example.com"}
       }}
    end

    def state, do: @state
    def auth_url, do: @auth_url
  end

  defmodule StubStrategyError do
    @moduledoc false

    def authorize_url(_config) do
      {:error, :strategy_error}
    end

    def callback(_config, _params) do
      {:error, :token_exchange_failed}
    end
  end

  defmodule StubProvider do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlowWeb.IntegrationLive.ConnectTest.StubStrategy

    @impl true
    def normalize_user(%{"sub" => sub}) when is_binary(sub) do
      {:ok,
       %{
         provider_user_id: sub,
         email: "stub@example.com",
         name: "Stub User",
         username: "stub@example.com",
         avatar_url: nil
       }}
    end

    def normalize_user(_), do: {:error, :missing_provider_user_id}
  end

  defmodule StubProviderCallbackError do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_callback_error/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlowWeb.IntegrationLive.ConnectTest.StubStrategyError

    @impl true
    def normalize_user(_), do: {:error, :should_not_be_called}
  end

  defmodule StubProviderAuthorizeError do
    @moduledoc false
    @behaviour MetricFlow.Integrations.Providers.Behaviour

    @impl true
    def config do
      [
        client_id: "stub-client-id",
        client_secret: "stub-client-secret",
        redirect_uri: "https://localhost/auth/stub_authorize_error/callback"
      ]
    end

    @impl true
    def strategy, do: MetricFlowWeb.IntegrationLive.ConnectTest.StubStrategyError

    @impl true
    def normalize_user(_), do: {:error, :should_not_be_called}
  end

  @stub_providers %{
    stub: MetricFlowWeb.IntegrationLive.ConnectTest.StubProvider,
    stub_callback_error: MetricFlowWeb.IntegrationLive.ConnectTest.StubProviderCallbackError,
    stub_authorize_error: MetricFlowWeb.IntegrationLive.ConnectTest.StubProviderAuthorizeError
  }

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp future_expires_at do
    DateTime.add(DateTime.utc_now(), 3_600, :second)
  end

  defp insert_integration!(user_id, provider, overrides \\ %{}) do
    defaults = %{
      user_id: user_id,
      provider: provider,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      refresh_token: "refresh-token-#{System.unique_integer([:positive])}",
      expires_at: future_expires_at(),
      granted_scopes: ["email", "profile"],
      provider_metadata: %{"provider_user_id" => "stub-user-id", "email" => "stub@example.com"}
    }

    attrs = Map.merge(defaults, overrides)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Setup — inject stub providers
  # ---------------------------------------------------------------------------

  setup do
    original = Application.get_env(:metric_flow, :oauth_providers)

    Application.put_env(:metric_flow, :oauth_providers, @stub_providers)

    on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :oauth_providers, original)
      else
        Application.delete_env(:metric_flow, :oauth_providers)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 (platform selection)"
  # ---------------------------------------------------------------------------

  describe "mount/3 (platform selection)" do
    test "renders the platform selection page for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Connect a Platform"
      end)
    end

    test "displays a platform card for each supported platform", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        assert has_element?(lv, "[data-platform]")
      end)
    end

    test "shows Not connected badge for a platform with no existing integration", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Not connected"
      end)
    end

    test "shows Connected badge for a platform that has an existing integration", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Connected"
      end)
    end

    test "renders a Connect button with phx-click and data-role attributes for each platform", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        assert has_element?(lv, "[data-role='connect-button'][phx-click='connect']")
      end)
    end

    test "renders a Reconnect button for a platform that is already connected", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Reconnect"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event connect"
  # ---------------------------------------------------------------------------

  describe "handle_event connect" do
    test "redirects to the OAuth provider authorization URL on success", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        assert {:error, {:redirect, %{to: redirect_url}}} =
                 lv
                 |> element("[data-role='connect-button'][phx-value-provider='stub']")
                 |> render_click()

        assert String.starts_with?(redirect_url, "https://")
      end)
    end

    test "redirect URL is the authorization URL returned by Integrations.authorize_url/1", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        assert {:error, {:redirect, %{to: redirect_url}}} =
                 lv
                 |> element("[data-role='connect-button'][phx-value-provider='stub']")
                 |> render_click()

        assert redirect_url == StubStrategy.auth_url()
      end)
    end

    test "shows an error flash for an unsupported provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        html =
          lv
          |> element("[data-role='connect-button'][phx-value-provider='unsupported_platform']")
          |> render_click()

        assert html =~ "This platform is not yet supported"
      end)
    end

    test "shows a generic error flash when authorize_url returns an unexpected error", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        html =
          lv
          |> element("[data-role='connect-button'][phx-value-provider='stub_authorize_error']")
          |> render_click()

        assert html =~ "Could not initiate connection. Please try again."
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3 (callback route)"
  # ---------------------------------------------------------------------------

  describe "mount/3 (callback route)" do
    test "assigns status :connected when code param is present and callback succeeds", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(
            conn,
            ~p"/integrations/oauth/callback/stub?code=valid-auth-code&state=#{StubStrategy.state()}"
          )

        html = render(lv)
        assert html =~ "Integration Active"
      end)
    end

    test "assigns status :connected and renders the integration confirmation view on success", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(
            conn,
            ~p"/integrations/oauth/callback/stub?code=valid-auth-code&state=#{StubStrategy.state()}"
          )

        html = render(lv)
        assert html =~ "View Integrations"
        assert html =~ "Connect another platform"
      end)
    end

    test "assigns status :error when the error param is present (e.g. access_denied)", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(conn, ~p"/integrations/oauth/callback/stub?error=access_denied")

        html = render(lv)
        assert html =~ "Connection Failed"
      end)
    end

    test "shows the Access was denied error message when the error param is access_denied", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(conn, ~p"/integrations/oauth/callback/stub?error=access_denied")

        html = render(lv)
        assert html =~ "Access was denied"
      end)
    end

    test "assigns status :error and shows a generic error message when handle_callback fails", %{
      conn: conn
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(
            conn,
            ~p"/integrations/oauth/callback/stub_callback_error?code=valid-auth-code&state=#{StubStrategy.state()}"
          )

        html = render(lv)
        assert html =~ "Connection Failed"
      end)
    end

    test "renders Try again and Back to integrations links on the error view", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} =
          live(conn, ~p"/integrations/oauth/callback/stub?error=access_denied")

        assert has_element?(lv, "a", "Try again")
        assert has_element?(lv, "a", "Back to integrations")
      end)
    end

    test "persists the integration record in the database on a successful callback", %{
      conn: conn
    } do
      user = user_fixture()
      scope = Scope.for_user(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, _html} =
          live(
            conn,
            ~p"/integrations/oauth/callback/stub?code=valid-auth-code&state=#{StubStrategy.state()}"
          )

        assert {:ok, integration} = MetricFlow.Integrations.get_integration(scope, :stub)
        assert integration.user_id == user.id
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "authentication"
  # ---------------------------------------------------------------------------

  describe "authentication" do
    test "redirects unauthenticated users to /users/log-in when visiting the platform selection page",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations/connect")
    end

    test "redirects unauthenticated users to /users/log-in when visiting a provider detail page",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations/connect/stub")
    end

    test "redirects unauthenticated users to /users/log-in when visiting the callback route",
         %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations/oauth/callback/stub?code=abc&state=xyz")
    end
  end
end
