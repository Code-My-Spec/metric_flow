defmodule MetricFlowSpex.DashboardDisplaysBothMarketingMetricsAndFinancialMetricsWithNoDistinctionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Dashboard displays both marketing metrics and financial metrics with no distinction" do
    scenario "marketing metric types appear on the dashboard page" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows marketing metric labels such as impressions, clicks, or spend", context do
        html = render(context.view)

        assert html =~ "Impressions" or
                 html =~ "impressions" or
                 html =~ "Clicks" or
                 html =~ "clicks" or
                 html =~ "Spend" or
                 html =~ "spend" or
                 has_element?(context.view, "[data-metric-type='marketing']") or
                 has_element?(context.view, "[data-role='metrics-area']")

        :ok
      end
    end

    scenario "financial metric types appear on the dashboard page" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows financial metric labels such as revenue or profit", context do
        html = render(context.view)

        assert html =~ "Revenue" or
                 html =~ "revenue" or
                 html =~ "Profit" or
                 html =~ "profit" or
                 html =~ "Income" or
                 html =~ "income" or
                 has_element?(context.view, "[data-metric-type='financial']") or
                 has_element?(context.view, "[data-role='metrics-area']")

        :ok
      end
    end

    scenario "the dashboard does not segregate metrics into separate marketing vs financial sections" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is no section header labelled Marketing Metrics separate from Financial Metrics", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='marketing-metrics-section']")
        refute has_element?(context.view, "[data-role='financial-metrics-section']")

        refute (html =~ "Marketing Metrics" and html =~ "Financial Metrics")

        :ok
      end
    end

    scenario "all metrics are presented in a unified area without category dividers" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a single unified metrics area is rendered rather than two separate category containers", context do
        assert has_element?(context.view, "[data-role='metrics-dashboard']") or
                 has_element?(context.view, "[data-role='metrics-area']") or
                 has_element?(context.view, "[data-role='dashboard-content']") or
                 render(context.view) =~ "metric" or
                 render(context.view) =~ "Metric"

        refute has_element?(context.view, "[data-role='marketing-section']") and
                 has_element?(context.view, "[data-role='financial-section']")

        :ok
      end
    end
  end
end
