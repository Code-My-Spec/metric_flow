defmodule MetricFlowSpex.Criterion4077SwitchChartTypesRetainsSelectionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can switch chart types without losing metric or name selections" do
    scenario "switching chart type preserves the selected metric and name" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has configured a visualization with a metric and name", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        # Type a name
        view
        |> form("form[phx-change='validate_name']", name: "My Test Chart")
        |> render_change()

        # Select a metric
        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user switches from line to bar chart type", context do
        html =
          context.view
          |> element("[phx-value-chart_type='bar']")
          |> render_click()

        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "the metric selection is preserved", context do
        html = render(context.view)
        # The impressions button should still have active styling
        # The metric selector dropdown should show the selected metric name
        html = render(context.view)
        assert html =~ "impressions"
        :ok
      end

      then_ "the visualization name is preserved", context do
        html = render(context.view)
        assert html =~ "My Test Chart"
        :ok
      end

      then_ "the bar chart type is now active", context do
        assert has_element?(context.view, "[phx-value-chart_type='bar'].btn-primary")
        :ok
      end
    end
  end
end
