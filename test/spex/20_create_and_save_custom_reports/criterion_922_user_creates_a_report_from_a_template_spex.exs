defmodule MetricFlowSpex.UserCreatesAReportFromATemplateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User creates a report from a template", criterion: 922 do
    scenario "choosing a template pre-populates the report" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user starting a new report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to start from a template", context do
        context.view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, context}
      end

      then_ "the report is pre-populated according to that template", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-role='visualization-card']")

        assert html =~ "Clicks" or html =~ "Spend" or html =~ "Impressions" or html =~ "ROAS"

        {:ok, context}
      end
    end
  end
end
