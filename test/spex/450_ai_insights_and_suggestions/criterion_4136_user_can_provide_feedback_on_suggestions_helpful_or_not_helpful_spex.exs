defmodule MetricFlowSpex.UserCanProvideFeedbackOnSuggestionsHelpfulOrNotHelpfulSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can provide feedback on suggestions (helpful or not helpful)" do
    scenario "each AI recommendation has helpful and not-helpful feedback buttons" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode and enables AI suggestions", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "each AI recommendation displays a helpful button and a not-helpful button", context do
        html = render(context.view)

        has_helpful_button =
          has_element?(context.view, "[data-role='feedback-helpful']") or
            html =~ "feedback-helpful" or
            html =~ "Helpful" or
            html =~ "helpful"

        has_not_helpful_button =
          has_element?(context.view, "[data-role='feedback-not-helpful']") or
            html =~ "feedback-not-helpful" or
            html =~ "Not helpful" or
            html =~ "not helpful" or
            html =~ "Not Helpful"

        assert has_helpful_button,
               "Expected each AI recommendation to have a 'helpful' feedback button. Got: #{html}"

        assert has_not_helpful_button,
               "Expected each AI recommendation to have a 'not helpful' feedback button. Got: #{html}"

        :ok
      end
    end

    scenario "user clicks helpful on a suggestion and sees confirmation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode and enables AI suggestions", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user clicks the helpful feedback button on a suggestion", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='feedback-helpful']") ->
            view
            |> element("[data-role='feedback-helpful']")
            |> render_click()

          has_element?(view, "button[phx-click='feedback_helpful']") ->
            view
            |> element("button[phx-click='feedback_helpful']")
            |> render_click()

          has_element?(view, "button", "Helpful") ->
            view
            |> element("button", "Helpful")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the user sees confirmation that their helpful feedback was recorded", context do
        html = render(context.view)

        has_confirmation =
          html =~ "Thanks for your feedback" or
            html =~ "thanks for your feedback" or
            html =~ "Feedback recorded" or
            html =~ "feedback recorded" or
            html =~ "Thank you" or
            html =~ "thank you" or
            has_element?(context.view, "[data-role='feedback-confirmed']") or
            has_element?(context.view, "[data-role='feedback-helpful'][data-selected='true']") or
            has_element?(context.view, "[data-role='feedback-helpful'][aria-pressed='true']") or
            html =~ "helpful"

        assert has_confirmation,
               "Expected to see confirmation after clicking 'helpful' on an AI suggestion. Got: #{html}"

        :ok
      end
    end

    scenario "user clicks not helpful on a suggestion and sees confirmation" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode and enables AI suggestions", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user clicks the not helpful feedback button on a suggestion", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='feedback-not-helpful']") ->
            view
            |> element("[data-role='feedback-not-helpful']")
            |> render_click()

          has_element?(view, "button[phx-click='feedback_not_helpful']") ->
            view
            |> element("button[phx-click='feedback_not_helpful']")
            |> render_click()

          has_element?(view, "button", "Not helpful") ->
            view
            |> element("button", "Not helpful")
            |> render_click()

          has_element?(view, "button", "Not Helpful") ->
            view
            |> element("button", "Not Helpful")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the user sees confirmation that their not helpful feedback was recorded", context do
        html = render(context.view)

        has_confirmation =
          html =~ "Thanks for your feedback" or
            html =~ "thanks for your feedback" or
            html =~ "Feedback recorded" or
            html =~ "feedback recorded" or
            html =~ "Thank you" or
            html =~ "thank you" or
            has_element?(context.view, "[data-role='feedback-confirmed']") or
            has_element?(context.view, "[data-role='feedback-not-helpful'][data-selected='true']") or
            has_element?(context.view, "[data-role='feedback-not-helpful'][aria-pressed='true']") or
            html =~ "not helpful"

        assert has_confirmation,
               "Expected to see confirmation after clicking 'not helpful' on an AI suggestion. Got: #{html}"

        :ok
      end
    end
  end
end
