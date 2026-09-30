defmodule MetricFlowSpex.Criterion860UserTogglesBetweenRawAndSmartAiModesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User toggles between Raw and Smart/AI modes", criterion: 860 do
    scenario "a user viewing Smart mode toggles to Raw mode" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user viewing correlation analysis in Smart/AI mode", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/correlations")

        view
        |> element("[data-role='mode-smart']")
        |> render_click()

        assert has_element?(view, "[data-role='smart-mode']")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they toggle to Raw mode", context do
        context.view
        |> element("[data-role='mode-raw']")
        |> render_click()

        {:ok, context}
      end

      then_ "the view switches to show raw mode results", context do
        refute has_element?(context.view, "[data-role='smart-mode']")
        {:ok, context}
      end
    end
  end
end
