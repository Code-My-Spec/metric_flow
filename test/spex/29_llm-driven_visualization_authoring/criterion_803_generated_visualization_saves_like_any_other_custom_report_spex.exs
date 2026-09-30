defmodule MetricFlowSpex.Criterion803SavesLikeAnyOtherCustomReportSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Generated visualization saves like any other custom report", criterion: 803 do
    scenario "saving a visualization built through the authoring workspace uses the standard save mechanism" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a visualization built through the authoring workspace", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Standard Save Chart"})

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user saves it", context do
        context.view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "it is saved using the same save mechanism as any other custom report", context do
        {:ok, _index_view, html} = live(context.owner_conn, "/app/visualizations")
        assert html =~ "Standard Save Chart"
        {:ok, context}
      end
    end
  end
end
