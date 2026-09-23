defmodule MetricFlowSpex.Criterion5058MalformedSpecShowsErrorSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Malformed or missing visualization spec shows a clear error state" do
    scenario "submitting a non-object JSON spec shows an error" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user has the spec editor open", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user enters a JSON array instead of an object", context do
        html =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render_blur(%{"value" => "[1, 2, 3]"})

        {:ok, Map.merge(context, %{html: html})}
      end

      then_ "a clear error is shown explaining the spec must be an object", context do
        html = render(context.view)
        assert html =~ "Spec must be a JSON object"
        :ok
      end
    end

    scenario "when no metric is selected, a placeholder message is shown instead of a blank chart" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "user loads the visualization editor without selecting anything", context do
        {:ok, view, html} = live(context.owner_conn, "/app/visualizations/new")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a placeholder message is displayed instead of a blank chart", context do
        assert has_element?(context.view, "[data-role='chart-placeholder']")
        assert context.html =~ "Select a metric"
        refute has_element?(context.view, "[data-role='vega-lite-chart']")
        :ok
      end
    end
  end
end
