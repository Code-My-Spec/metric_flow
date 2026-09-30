defmodule MetricFlowSpex.Criterion189UserCanToggleBetweenRawAndSmartAiModesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can toggle between Raw and Smart/AI modes", criterion: 189 do
    scenario "a user switches from Raw mode to Smart mode and back" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing the correlations page in Raw mode", context do
        MetricFlowSpex.Fixtures.create_correlation_result!(context.owner_email, %{
          metric_name: "ad_spend",
          goal_metric_name: "revenue",
          coefficient: 0.5
        })

        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        assert has_element?(view, "table")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they toggle to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      then_ "the view switches to Smart mode", context do
        assert has_element?(context.view, "[data-role='smart-mode']")
        refute has_element?(context.view, "[data-role='correlations-table']")
        {:ok, context}
      end

      when_ "they toggle back to Raw mode", context do
        context.view
        |> element("[data-role='mode-raw']")
        |> render_click()

        {:ok, context}
      end

      then_ "the view switches back to Raw mode", context do
        refute has_element?(context.view, "[data-role='smart-mode']")
        {:ok, context}
      end
    end
  end
end
