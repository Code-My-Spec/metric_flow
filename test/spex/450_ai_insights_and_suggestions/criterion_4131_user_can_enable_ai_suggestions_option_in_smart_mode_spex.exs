defmodule MetricFlowSpex.UserCanEnableAiSuggestionsOptionInSmartModeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can enable AI Suggestions option in Smart mode" do
    scenario "user in Smart mode sees the Enable AI Suggestions option" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode", context do
        view = context.view
        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees an option to enable AI suggestions", context do
        html = render(context.view)

        has_ai_option =
          has_element?(context.view, "[data-role='enable-ai-suggestions']") or
            html =~ "Enable AI Suggestions" or
            html =~ "AI Suggestions"

        assert has_ai_option,
               "Expected an 'Enable AI Suggestions' option to be visible in Smart mode. Got: #{html}"

        :ok
      end
    end

    scenario "user in Raw mode does not see the AI suggestions option" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page in Raw mode", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the AI suggestions option is not visible in Raw mode", context do
        html = render(context.view)

        refute has_element?(context.view, "[data-role='enable-ai-suggestions']"),
               "Expected 'Enable AI Suggestions' toggle to be absent in Raw mode. Got: #{html}"

        :ok
      end
    end

    scenario "user toggles AI suggestions on in Smart mode and sees confirmation" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user switches to Smart mode", context do
        context.view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      when_ "the user enables AI suggestions", context do
        context.view
        |> element("[data-role='enable-ai-suggestions']")
        |> render_click()

        {:ok, context}
      end

      then_ "the user sees confirmation that AI suggestions are enabled", context do
        html = render(context.view)

        has_confirmation =
          has_element?(context.view, "[data-role='ai-suggestions-enabled']") or
            html =~ "AI suggestions enabled" or
            html =~ "AI Suggestions enabled" or
            html =~ "AI suggestions active" or
            html =~ "enabled"

        assert has_confirmation,
               "Expected confirmation that AI suggestions are enabled. Got: #{html}"

        :ok
      end
    end
  end
end
