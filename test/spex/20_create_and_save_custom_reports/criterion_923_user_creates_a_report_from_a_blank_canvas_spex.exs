defmodule MetricFlowSpex.UserCreatesAReportFromABlankCanvasSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User creates a report from a blank canvas", criterion: 923 do
    scenario "choosing a blank canvas gives an empty report" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user starting a new report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to start from a blank canvas", context do
        context.view
        |> element("[data-role='template-card-blank']")
        |> render_click()

        {:ok, context}
      end

      then_ "they get an empty report ready to build from scratch", context do
        assert has_element?(context.view, "[data-role='empty-canvas']")
        {:ok, context}
      end
    end
  end
end
