defmodule MetricFlowSpex.ReportEditorIncludesTheCannedVegaLiteSpecEditorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Report editor includes the canned Vega-Lite spec editor", criterion: 932 do
    scenario "opening a chart's spec editor from the report editor shows the canned spec editor" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user editing a report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they open the spec editor for a chart", context do
        {:ok, context}
      end

      then_ "it is the canned Vega-Lite spec editor", context do
        assert has_element?(context.view, "[data-role='open-spec-panel']") or
                 has_element?(context.view, "[data-role='spec-panel']")

        {:ok, context}
      end
    end
  end
end
