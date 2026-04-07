defmodule MetricFlowSpex.Criterion4150EditVegaLiteSpecDirectlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can edit Vega-Lite spec directly if desired (advanced mode)" do
    scenario "visualization editor has a spec editor textarea for direct JSON editing" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "user is on the visualization editor with a metric selected", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "user opens the spec editor", context do
        context.view
        |> element("[data-role='toggle-spec-editor']")
        |> render_click()

        {:ok, context}
      end

      then_ "a textarea with the Vega-Lite JSON spec is displayed", context do
        assert has_element?(context.view, "[data-role='vega-spec-textarea']")

        textarea_html =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert textarea_html =~ "mark"
        :ok
      end
    end
  end
end
