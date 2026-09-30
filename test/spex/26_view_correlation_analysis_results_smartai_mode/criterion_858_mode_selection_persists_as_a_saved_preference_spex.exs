defmodule MetricFlowSpex.Criterion858ModeSelectionPersistsAsASavedPreferenceSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Mode selection persists as a saved preference", criterion: 858 do
    scenario "a user who selected Smart mode still sees Smart mode in a later session" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has selected Smart mode instead of Raw mode", context do
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

      then_ "their correlation view still opens in Smart mode", context do
        assert has_element?(context.view, "[data-role='smart-mode']"),
               "Expected the correlations page to reopen in Smart mode after the user's earlier selection"

        {:ok, context}
      end
    end
  end
end
