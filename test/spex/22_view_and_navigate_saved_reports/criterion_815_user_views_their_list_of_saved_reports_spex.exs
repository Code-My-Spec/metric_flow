defmodule MetricFlowSpex.Criterion815UserViewsListOfSavedReportsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User views their list of saved reports", criterion: 815 do
    scenario "opening the reports section shows all saved reports" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription
      given_ :owner_has_metrics

      given_ "a user with several saved reports", context do
        for {metric, name} <- [
              {"impressions", "Report One"},
              {"clicks", "Report Two"},
              {"conversions", "Report Three"}
            ] do
          {:ok, view, _html} = live(context.owner_conn, "/app/visualizations/new")

          view
          |> element("[phx-value-metric='#{metric}']")
          |> render_click()

          view
          |> element("form[phx-change='validate_name']")
          |> render_change(%{"name" => name})

          view
          |> element("[data-role='save-visualization-btn']")
          |> render_click()
        end

        {:ok, context}
      end

      when_ "they open the reports section", context do
        {:ok, view, html} = live(context.owner_conn, "/app/reports")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they see a list of all their saved reports", context do
        assert context.html =~ "Report One"
        assert context.html =~ "Report Two"
        assert context.html =~ "Report Three"
        {:ok, context}
      end
    end
  end
end
