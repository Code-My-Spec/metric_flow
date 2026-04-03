defmodule MetricFlowWeb.IntegrationLive.ConnectTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Stub providers
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

  @stub_providers %{
    stub: MetricFlowWeb.IntegrationLive.ConnectTest.StubProvider
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
  # Setup
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
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders connect page with provider cards in a grid" do
    test "shows provider cards", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Connect a Provider"
        assert html =~ "data-platform"
      end)
    end
  end

  describe "shows Connected badge for providers with active integrations" do
    test "displays Connected badge", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :stub)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Connected"
      end)
    end
  end

  describe "shows Not connected badge for providers without integrations" do
    test "displays Not connected badge", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect")

        assert html =~ "Not connected"
      end)
    end
  end

  describe "shows Connect button for each provider card" do
    test "displays connect button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect")

        assert has_element?(lv, "[data-role='connect-button']")
      end)
    end
  end

  describe "renders per-provider detail view with OAuth connect button" do
    test "shows detail view with OAuth button", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations/connect/stub")

        assert is_binary(html)
        assert has_element?(lv, "[data-role='oauth-connect-button']")
      end)
    end
  end

  describe "shows connected status and account email on per-provider view when connected" do
    test "displays connected status with email", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :stub)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/connect/stub")

        assert html =~ "Connected"
        assert html =~ "stub@example.com"
      end)
    end
  end

  describe "shows back to integrations link on per-provider view" do
    test "displays back link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/connect/stub")

        assert has_element?(lv, "a[href='/integrations']")
      end)
    end
  end

  describe "redirects unauthenticated users to login" do
    test "redirects to /users/log-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/integrations/connect")
    end
  end
end
