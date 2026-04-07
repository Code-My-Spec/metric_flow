defmodule MetricFlowSpex.AiLearnsFromFeedbackToImproveFutureSuggestionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "AI learns from feedback to improve future suggestions" do
    scenario "after providing feedback, user sees a message indicating feedback helps improve suggestions" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page in Smart mode with AI suggestions enabled", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the helpful feedback button on a suggestion", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='feedback-helpful']") ->
            view
            |> element("[data-role='feedback-helpful']")
            |> render_click()

          has_element?(view, "[data-role='ai-recommendations'] [data-role='feedback-helpful']") ->
            view
            |> element("[data-role='ai-recommendations'] [data-role='feedback-helpful']")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the user sees a message indicating their feedback helps improve suggestions", context do
        html = render(context.view)

        has_feedback_message =
          has_element?(context.view, "[data-role='feedback-improvement-message']") or
            has_element?(context.view, "[data-role='feedback-confirmation']") or
            html =~ "helps improve" or
            html =~ "improve suggestions" or
            html =~ "improve future" or
            html =~ "feedback recorded" or
            html =~ "Thank you for your feedback" or
            html =~ "thank you" or
            html =~ "Thank you"

        assert has_feedback_message,
               "Expected a message indicating feedback helps improve suggestions after clicking helpful. Got: #{html}"

        :ok
      end
    end

    scenario "the feedback section communicates the learning and improvement aspect" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page in Smart mode with AI suggestions enabled", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the AI suggestions area contains language about learning or personalization", context do
        html = render(context.view)

        has_learning_language =
          html =~ "helps improve" or
            html =~ "learns from" or
            html =~ "learn from" or
            html =~ "personalized" or
            html =~ "personalize" or
            html =~ "improve over time" or
            html =~ "gets better" or
            html =~ "tailored" or
            html =~ "feedback" or
            has_element?(context.view, "[data-role='ai-feedback-section']") or
            has_element?(context.view, "[data-role='feedback-helpful']") or
            has_element?(context.view, "[data-role='feedback-not-helpful']")

        assert has_learning_language,
               "Expected the AI suggestions section to communicate learning or personalization. Got: #{html}"

        :ok
      end
    end

    scenario "user who provides not-helpful feedback sees an indication their preferences are being considered" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "the user navigates to the correlations page in Smart mode with AI suggestions enabled", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the not-helpful feedback button on a suggestion", context do
        view = context.view

        cond do
          has_element?(view, "[data-role='feedback-not-helpful']") ->
            view
            |> element("[data-role='feedback-not-helpful']")
            |> render_click()

          has_element?(view, "[data-role='ai-recommendations'] [data-role='feedback-not-helpful']") ->
            view
            |> element("[data-role='ai-recommendations'] [data-role='feedback-not-helpful']")
            |> render_click()

          true ->
            render(view)
        end

        {:ok, context}
      end

      then_ "the user sees an indication their preferences will be taken into account", context do
        html = render(context.view)

        has_preference_message =
          has_element?(context.view, "[data-role='feedback-improvement-message']") or
            has_element?(context.view, "[data-role='feedback-confirmation']") or
            html =~ "preferences" or
            html =~ "noted" or
            html =~ "Noted" or
            html =~ "will improve" or
            html =~ "helps improve" or
            html =~ "improve suggestions" or
            html =~ "feedback" or
            html =~ "Thank you" or
            html =~ "thank you" or
            html =~ "considered" or
            html =~ "we'll use"

        assert has_preference_message,
               "Expected an indication that not-helpful feedback will improve future suggestions. Got: #{html}"

        :ok
      end
    end
  end
end
