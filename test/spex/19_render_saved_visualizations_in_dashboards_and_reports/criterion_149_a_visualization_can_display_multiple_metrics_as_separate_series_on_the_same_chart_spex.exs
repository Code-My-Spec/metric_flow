defmodule MetricFlowSpex.Criterion149MultipleMetricsAsSeparateSeriesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "A visualization can display multiple metrics as separate series on the same chart",
    criterion: 149 do
    scenario "binding two metrics produces a layered spec with one series per metric" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "the user opens the visualization editor and selects two metrics", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[phx-value-metric='clicks']")
        |> render_click()

        view
        |> element("[data-role='open-spec-panel']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the spec contains one series per bound metric rather than a single merged series", context do
        spec_text =
          context.view
          |> element("[data-role='vega-spec-textarea']")
          |> render()

        assert spec_text =~ "impressions"
        assert spec_text =~ "clicks"
        assert spec_text =~ "layer"
        {:ok, context}
      end
    end
  end
end
