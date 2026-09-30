defmodule MetricFlowSpex.Criterion788MultipleChartsAddedForComparisonSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Multiple charts are added to one view for comparison", criterion: 788 do
    scenario "a user adds a second chart alongside the first on a dashboard" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a dashboard view with one chart already added", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        view
        |> element("[phx-click='select_metric'][phx-value-metric='impressions']")
        |> render_click()

        view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user adds a second chart", context do
        context.view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        context.view
        |> element("[phx-click='select_metric'][phx-value-metric='clicks']")
        |> render_click()

        context.view
        |> element("[data-role='confirm-add-btn']")
        |> render_click()

        {:ok, context}
      end

      then_ "both charts are displayed together in the same view for comparison", context do
        assert context.view
               |> element("[data-role='visualization-canvas']")
               |> render() =~ "impressions"

        html =
          context.view
          |> element("[data-role='visualization-canvas']")
          |> render()

        assert html =~ "clicks"

        assert context.view
               |> element("[data-role='visualization-canvas']")
               |> render()
               |> then(&Regex.scan(~r/data-role="visualization-card"/, &1))
               |> length() == 2

        {:ok, context}
      end
    end
  end
end
