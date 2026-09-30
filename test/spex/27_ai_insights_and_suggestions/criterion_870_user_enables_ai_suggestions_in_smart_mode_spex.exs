defmodule MetricFlowSpex.Criterion870UserEnablesAiSuggestionsInSmartModeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User enables AI Suggestions in Smart mode", criterion: 870 do
    scenario "a user viewing correlation analysis in Smart mode enables the AI Suggestions option" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing correlation analysis in Smart mode", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they enable the AI Suggestions option", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "AI-powered suggestions become visible", context do
        html = render(context.view)

        assert html =~ "recommendations" or html =~ "Recommendations" or
                 has_element?(context.view, "[data-role='ai-recommendations']"),
               "Expected AI-powered suggestions to become visible, got: #{html}"

        {:ok, context}
      end
    end
  end
end
