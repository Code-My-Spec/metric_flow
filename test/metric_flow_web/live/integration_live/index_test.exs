defmodule MetricFlowWeb.IntegrationLive.IndexTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Stub providers
  # ---------------------------------------------------------------------------

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
    def strategy, do: __MODULE__

    def authorize_url(_config), do: {:error, :not_used_in_index}
    def callback(_config, _params), do: {:error, :not_used_in_index}

    @impl true
    def normalize_user(_), do: {:error, :not_used_in_index}
  end

  @stub_providers %{
    google_analytics: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    google_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    google_search_console: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    facebook_ads: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider,
    quickbooks: MetricFlowWeb.IntegrationLive.IndexTest.StubProvider
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

  describe "renders integrations page with header and Connect a Platform link" do
    test "shows header and connect link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Integrations"
        assert html =~ "Manage your connected marketing platforms"
        assert has_element?(lv, "a[href='/integrations/connect']", "Connect a Platform")
      end)
    end
  end

  describe "shows empty state when no integrations are connected" do
    test "displays empty state message", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations")

        assert html =~ "No platforms connected yet."
        assert has_element?(lv, "a[href='/integrations/connect']", "Connect your first platform")
        refute html =~ "Connected Platforms"
      end)
    end
  end

  describe "displays connected platforms with name, description, and Connected badge" do
    test "shows connected platform details", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Connected Platforms"
        assert html =~ "Google Ads"
        assert html =~ "Paid search and display advertising"
        assert has_element?(lv, "[data-platform='google_ads'][data-status='connected']")
        assert html =~ "Connected"
      end)
    end
  end

  describe "shows Sync Now, Edit Accounts, Manage, and Disconnect buttons for connected platforms" do
    test "shows all action buttons", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        assert has_element?(lv, "[phx-click='sync'][phx-value-platform='google_ads']")
        assert has_element?(lv, "[data-role='edit-integration-accounts']")
        assert has_element?(lv, "a[href='/integrations/connect/google_ads']", "Manage")
        assert has_element?(lv, "[data-role='disconnect-integration']")
      end)
    end
  end

  describe "displays available platforms section for unconnected providers" do
    test "shows available platforms with connect links", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/integrations")

        assert html =~ "Available Platforms"
        assert has_element?(lv, "[data-platform='google_analytics'][data-status='available']")
        assert has_element?(lv, "[data-role='reconnect-integration']", "Connect Facebook")
      end)
    end
  end

  describe "triggers sync and shows success flash on Sync Now click" do
    test "shows sync started flash", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads, %{provider_metadata: %{"provider_user_id" => "stub-user-id", "email" => "stub@example.com", "customer_id" => "1234567890"}})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        html =
          lv
          |> element("[phx-click='sync'][phx-value-platform='google_ads']")
          |> render_click()

        assert html =~ "Sync started for"
      end)
    end
  end

  describe "shows error flash when syncing a non-existent integration" do
    test "shows not found error", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        html = render_click(lv, "sync", %{"provider" => "google_ads", "platform" => "google_ads"})

        assert html =~ "integration not found"
      end)
    end
  end

  describe "opens disconnect confirmation modal on Disconnect click" do
    test "shows modal with confirm and cancel", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        html =
          lv
          |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
          |> render_click()

        assert html =~ "Disconnect"
        assert html =~ "Historical data will remain"
        assert has_element?(lv, "[data-role='confirm-disconnect']")
        assert has_element?(lv, "[data-role='cancel-disconnect']")
      end)
    end
  end

  describe "disconnects provider and shows success flash on confirm" do
    test "deletes integration and shows flash", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
        |> render_click()

        html =
          lv
          |> element("[data-role='confirm-disconnect']")
          |> render_click()

        assert html =~ "Disconnected from"
        assert html =~ "Historical data is retained"
        refute has_element?(lv, "[data-role='confirm-disconnect']")
        assert {:error, :not_found} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end
  end

  describe "cancels disconnect modal without modifying data" do
    test "closes modal and preserves integration", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      insert_integration!(user.id, :google_ads)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations")

        lv
        |> element("[data-platform='google_ads'] [data-role='disconnect-integration']")
        |> render_click()

        lv
        |> element("[data-role='cancel-disconnect']")
        |> render_click()

        refute has_element?(lv, "[data-role='confirm-disconnect']")
        assert {:ok, _integration} = MetricFlow.Integrations.get_integration(scope, :google_ads)
      end)
    end
  end
end
