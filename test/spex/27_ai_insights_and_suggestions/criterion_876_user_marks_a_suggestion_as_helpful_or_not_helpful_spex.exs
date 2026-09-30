defmodule MetricFlowSpex.Criterion876UserMarksASuggestionAsHelpfulOrNotHelpfulSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User marks a suggestion as helpful or not helpful", criterion: 876 do
    scenario "a user has received an AI suggestion and marks it as helpful" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has received an AI suggestion", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "they mark it as helpful or not helpful", context do
        context.view
        |> element("[data-role='feedback-helpful']")
        |> render_click()

        {:ok, context}
      end

      then_ "their feedback is recorded", context do
        assert has_element?(context.view, "[data-role='feedback-confirmation']"),
               "Expected feedback confirmation to be recorded"

        {:ok, context}
      end
    end
  end
end
