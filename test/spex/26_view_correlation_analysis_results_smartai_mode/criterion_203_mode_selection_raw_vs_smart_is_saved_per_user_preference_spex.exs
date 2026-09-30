defmodule MetricFlowSpex.Criterion203ModeSelectionSavedPerUserPreferenceSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Mode selection (Raw vs Smart) is saved per user preference", criterion: 203 do
    scenario "a user's Smart mode selection is remembered when they return" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user selects Smart mode", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        {:ok, context}
      end

      when_ "they return in a later session", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the mode selection (Raw vs Smart) is saved per user preference, so it opens in Smart mode", context do
        assert has_element?(context.view, "[data-role='smart-mode']"),
               "Expected the correlations page to remember the user's Smart mode preference across sessions"

        {:ok, context}
      end
    end
  end
end
