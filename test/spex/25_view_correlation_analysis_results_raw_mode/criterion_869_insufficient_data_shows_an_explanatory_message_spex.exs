defmodule MetricFlowSpex.Criterion869InsufficientDataShowsAnExplanatoryMessageSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Insufficient data shows an explanatory message", criterion: 869 do
    scenario "an account with too little synced history sees the minimum data requirements explained" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "an account with too little synced history to meet the minimum data requirement", context do
        {:ok, context}
      end

      when_ "the user views correlation analysis", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='run-correlations']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they see a message explaining the minimum data requirements rather than an empty or broken list", context do
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
