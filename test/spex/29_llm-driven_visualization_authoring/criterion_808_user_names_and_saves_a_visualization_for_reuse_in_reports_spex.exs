defmodule MetricFlowSpex.Criterion808NamesAndSavesForReuseSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User names and saves a visualization for reuse in reports", criterion: 808 do
    scenario "a user builds a visualization and names and saves it" do
      given_(:user_logged_in_as_owner)
      given_(:owner_has_active_subscription)
      given_(:owner_has_metrics)

      given_ "a user has built a visualization in the authoring workspace", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

        view
        |> element("[phx-value-metric='impressions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they name and save it", context do
        context.view
        |> element("form[phx-change='validate_name']")
        |> render_change(%{"name" => "Reusable Report Chart"})

        context.view
        |> element("[data-role='save-visualization-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "it becomes available for inclusion in custom reports", context do
        {:ok, _index_view, html} = live(context.owner_conn, "/app/visualizations")
        assert html =~ "Reusable Report Chart"
        {:ok, context}
      end
    end
  end
end
