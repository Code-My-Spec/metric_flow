defmodule MetricFlowWeb.IntegrationLive.ProviderDashboardTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_integration(user, provider, opts \\ %{}) do
    defaults = %{
      user_id: user.id,
      provider: provider,
      access_token: "test_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: %{"email" => user.email}
    }

    %Integration{}
    |> Integration.changeset(Map.merge(defaults, opts))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions from spec
  # ---------------------------------------------------------------------------

  describe "renders provider dashboard with provider name and connection status" do
    test "renders provider dashboard with provider name and connection status", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        assert html =~ "Google Analytics"
        assert html =~ "Connected"
      end)
    end
  end

  describe "shows metric cards with chart containers for the provider" do
    test "shows metric cards with chart containers for the provider", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        assert has_element?(lv, "[data-role='metric-card']")
      end)
    end
  end

  describe "shows sync history section with recent sync entries" do
    test "shows sync history section with recent sync entries", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        assert has_element?(lv, "[data-role='sync-history-section']")
      end)
    end
  end

  describe "triggers manual sync and shows sync started flash" do
    test "triggers manual sync and shows sync started flash", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        html =
          lv
          |> element("[data-role='sync-now']")
          |> render_click()

        assert html =~ "Sync started"
      end)
    end
  end

  describe "changes date range filter and re-renders metric charts" do
    test "changes date range filter and re-renders metric charts", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_analytics)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        html = render_change(lv, "change_date_range", %{"date_range" => "last_90_days"})

        assert is_binary(html)
        assert has_element?(lv, "[data-role='metric-card']")
      end)
    end
  end

  describe "shows reviews section for google_business provider" do
    test "shows reviews section for google_business provider", %{conn: conn} do
      user = user_fixture()
      create_integration(user, :google_business)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_business/dashboard")

        assert has_element?(lv, "[data-role='reviews-section']")
      end)
    end
  end

  describe "shows empty state with connect link when provider has no integration" do
    test "shows empty state with connect link when provider has no integration", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/integrations/google_analytics/dashboard")

        assert has_element?(lv, "[data-role='empty-state']")
      end)
    end
  end

  describe "redirects to integrations for unrecognized provider" do
    test "redirects to integrations for unrecognized provider", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/integrations"}}} =
                 live(conn, ~p"/integrations/nonexistent_provider/dashboard")
      end)
    end
  end
end
