defmodule MetricFlowWeb.ReportLive.ShowTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.MetricsFixtures

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp visualization_fixture(user, attrs \\ %{}) do
    defaults = %{
      name: "Test Report #{System.unique_integer([:positive])}",
      user_id: user.id,
      vega_spec: %{"$schema" => "https://vega.github.io/schema/vega-lite/v5.json"},
      shareable: false
    }

    %Visualization{}
    |> Visualization.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # Test Assertions
  # ---------------------------------------------------------------------------

  describe "renders report show page with report name and chart" do
    test "renders report show page with report name and chart", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user, %{name: "Q1 Revenue Report"})
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, html} = live(conn, ~p"/reports/#{report.id}")

        assert html =~ "Q1 Revenue Report"
        assert has_element?(lv, "[data-role='report-chart']")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  describe "shows back to reports link" do
    test "shows back to reports link", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports/#{report.id}")

        assert has_element?(lv, "[data-role='back-link']")
        assert render(lv) =~ "Back to Reports"
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  describe "redirects with error flash when report ID not found" do
    test "redirects with error flash when report ID not found", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      capture_log(fn ->
        assert {:error, {:redirect, %{to: "/reports", flash: flash}}} =
                 live(conn, ~p"/reports/999999")

        assert flash["error"] =~ "not found"
        send(self(), :done)
      end)

      assert_receive :done
    end
  end

  describe "displays metric summary cards below the chart" do
    test "displays metric summary cards below the chart", %{conn: conn} do
      user = user_fixture()
      report = visualization_fixture(user)
      conn = log_in_user(conn, user)

      # Seed a metric so metric_names is non-empty
      insert_metric!(user)

      capture_log(fn ->
        {:ok, lv, _html} = live(conn, ~p"/reports/#{report.id}")

        assert has_element?(lv, "[data-role='metric-summaries']")
        assert has_element?(lv, "[data-role='metric-summary-card']")
        send(self(), :done)
      end)

      assert_receive :done
    end
  end
end
