defmodule MetricFlowSpex.Criterion197IfInsufficientDataExistsUserSeesMessageExplainingMinimumRequirementsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If insufficient data exists, user sees message explaining minimum requirements",
    criterion: 197 do
    scenario "a user with too little synced history is shown the minimum data requirements" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "an account with too little synced metric history", context do
        {:ok, goals_view, _html} = live(context.owner_conn, "/app/correlations/goals")
        {:ok, Map.put(context, :goals_view, goals_view)}
      end

      when_ "the user views correlation analysis", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='run-correlations']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see a message explaining the minimum data requirements", context do
        assert has_element?(context.view, "[data-role='insufficient-data-warning']")

        warning_html =
          context.view
          |> element("[data-role='insufficient-data-warning']")
          |> render()

        assert warning_html =~ "30 days",
               "Expected the message to explain the minimum data requirement, got: #{warning_html}"

        {:ok, context}
      end
    end
  end
end
