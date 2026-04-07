defmodule MetricFlowSpex.Criterion4145NaturalLanguagePromptSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can enter natural language description of desired report" do
    scenario "report generator page has a prompt textarea" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "user navigates to the report generator", context do
        {:ok, view, html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a prompt input is visible for entering a description", context do
        assert has_element?(context.view, "[data-role='prompt-input']")
        assert has_element?(context.view, "[data-role='generate-btn']")
        :ok
      end
    end

    scenario "user can type a prompt and the form accepts it" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the report generator page", context do
        {:ok, view, _html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user types a natural language description", context do
        html =
          context.view
          |> render_change("update_prompt", %{"prompt" => "Show me weekly revenue over the last 90 days"})

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the generate button becomes enabled", context do
        refute has_element?(context.view, "[data-role='generate-btn'][disabled]")
        :ok
      end
    end
  end
end
