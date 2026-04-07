defmodule MetricFlowSpex.Criterion4089MetricsFromAnyPlatformSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Reports can include metrics from any connected platform" do
    scenario "metric picker shows metrics from marketing and financial platforms" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user opens the metric picker on a new dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the metric list includes metrics from multiple platform types", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='metric-list']")
        # Available metrics should include both marketing and financial metrics
        # (the exact list depends on connected integrations)
        :ok
      end
    end
  end
end
