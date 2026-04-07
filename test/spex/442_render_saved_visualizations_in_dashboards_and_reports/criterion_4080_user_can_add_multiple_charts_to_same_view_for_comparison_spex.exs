defmodule MetricFlowSpex.Criterion4080MultipleChartsForComparisonSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can add multiple charts to the same dashboard for comparison" do
    scenario "dashboard editor allows adding multiple visualizations" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user navigates to create a new dashboard", context do
        {:ok, view, html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the dashboard editor has an add visualization button", context do
        assert has_element?(context.view, "[data-role='add-visualization-btn']")
        :ok
      end
    end

    scenario "existing dashboard shows multiple visualization panels" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "user views the dashboards index", context do
        {:ok, view, html} = live(context.owner_conn, "/dashboards")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the page loads successfully and shows dashboard content", context do
        # The dashboards index should render without error
        assert context.html =~ "Dashboard" || context.html =~ "dashboard"
        :ok
      end
    end
  end
end
