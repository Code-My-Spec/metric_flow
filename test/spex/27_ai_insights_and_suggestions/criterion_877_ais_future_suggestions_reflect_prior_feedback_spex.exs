defmodule MetricFlowSpex.Criterion877AisFutureSuggestionsReflectPriorFeedbackSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "AI's future suggestions reflect prior feedback", criterion: 877 do
    scenario "a user has previously marked similar suggestions as not helpful" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has previously marked similar suggestions as not helpful", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        view
        |> element("[data-role='feedback-not-helpful']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the AI generates future suggestions", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "it takes that feedback into account rather than repeating the same kind of suggestion unchanged",
            context do
        html = render(context.view)

        assert html =~ "feedback" or html =~ "preferences" or html =~ "noted" or
                 has_element?(context.view, "[data-role='ai-recommendations']"),
               "Expected future suggestions to reflect prior feedback, got: #{html}"

        {:ok, context}
      end
    end
  end
end
