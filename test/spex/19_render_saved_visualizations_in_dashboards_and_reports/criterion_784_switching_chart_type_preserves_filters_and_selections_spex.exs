defmodule MetricFlowSpex.Criterion784SwitchingChartTypePreservesSelectionsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Switching chart type preserves filters and selections", criterion: 784 do
    scenario "a visualization with a selected metric switches chart type from bar to line" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a visualization with an active metric selection and bar chart type", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[phx-value-chart_type='bar']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches its chart type to line", context do
        context.view
        |> element("[phx-value-chart_type='line']")
        |> render_click()

        {:ok, context}
      end

      then_ "the existing metric selection remains applied to the new chart type", context do
        html = render(context.view)
        assert html =~ "Select Metric" == false
        assert has_element?(context.view, "[data-role='vega-lite-chart']")

        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']", "")
          |> has_element?()

        assert spec_text or has_element?(context.view, "[data-role='vega-lite-chart']")
        {:ok, context}
      end
    end
  end
end
