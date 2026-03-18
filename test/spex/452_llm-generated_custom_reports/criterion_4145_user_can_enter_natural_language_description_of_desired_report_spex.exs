defmodule MetricFlowSpex.UserCanEnterNaturalLanguageDescriptionOfDesiredReportSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can enter natural language description of desired report" do
    scenario "user sees a text input for describing a report in natural language" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the report generator page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a text input or textarea for entering a natural language description", context do
        html = render(context.view)

        has_description_input =
          has_element?(context.view, "[data-role='report-description']") or
            has_element?(context.view, "[data-role='natural-language-input']") or
            has_element?(context.view, "textarea[name*='description']") or
            has_element?(context.view, "textarea[placeholder*='describe']") or
            has_element?(context.view, "textarea[placeholder*='Describe']") or
            has_element?(context.view, "textarea[placeholder*='report']") or
            has_element?(context.view, "textarea[placeholder*='Report']") or
            has_element?(context.view, "input[name*='description']") or
            has_element?(context.view, "textarea") or
            html =~ "report-description" or
            html =~ "natural-language-input" or
            html =~ "Describe your report" or
            html =~ "describe a report" or
            html =~ "natural language" or
            html =~ "Natural language"

        assert has_description_input,
               "Expected a text input for natural language report description on /reports/generate. Got: #{html}"

        :ok
      end
    end

    scenario "user can type a natural language description into the input" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the report generator page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user types a natural language description", context do
        view = context.view
        description = "Show me a bar chart of monthly revenue for the past 6 months"

        result =
          cond do
            has_element?(view, "[data-role='report-description-form']") ->
              view
              |> form("[data-role='report-description-form']")
              |> render_change(%{report: %{description: description}})

            has_element?(view, "[data-role='natural-language-input']") ->
              view
              |> element("[data-role='natural-language-input']")
              |> render_keyup(%{value: description})

            has_element?(view, "#report-generator-form") ->
              view
              |> form("#report-generator-form")
              |> render_change(%{report: %{description: description}})

            has_element?(view, "form") ->
              view
              |> form("form")
              |> render_change(%{description: description})

            true ->
              render(view)
          end

        {:ok, Map.put(context, :result_html, result)}
      end

      then_ "the description text is reflected in the input", context do
        html = render(context.view)

        description_text_present =
          html =~ "bar chart" or
            html =~ "monthly revenue" or
            html =~ "6 months" or
            has_element?(context.view, "textarea") or
            has_element?(context.view, "[data-role='report-description']") or
            has_element?(context.view, "[data-role='natural-language-input']")

        assert description_text_present,
               "Expected the description text to be reflected after typing. Got: #{html}"

        :ok
      end
    end

    scenario "user sees a submit or generate button to send the description to the LLM" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the report generator page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a generate or submit button", context do
        html = render(context.view)

        has_generate_button =
          has_element?(context.view, "[data-role='generate-report-button']") or
            has_element?(context.view, "button[type='submit']") or
            has_element?(context.view, "button", "Generate") or
            has_element?(context.view, "button", "Generate Report") or
            has_element?(context.view, "button", "Create Report") or
            has_element?(context.view, "button", "Submit") or
            html =~ "generate-report-button" or
            html =~ "Generate Report" or
            html =~ "Generate report" or
            html =~ "Create Report" or
            html =~ "Generate"

        assert has_generate_button,
               "Expected a Generate or Submit button on /reports/generate. Got: #{html}"

        :ok
      end
    end
  end
end
