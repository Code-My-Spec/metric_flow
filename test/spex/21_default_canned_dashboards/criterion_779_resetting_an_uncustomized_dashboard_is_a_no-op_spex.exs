defmodule MetricFlowSpex.ResettingAnUncustomizedDashboardIsANoOpSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Resetting an uncustomized dashboard is a no-op", criterion: 779 do
    scenario "a user viewing a canned dashboard they have never customized chooses to reset it" do
      given_(:user_logged_in_as_owner)

      given_ "a user is viewing a canned dashboard they have never customized", context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they choose to reset it", context do
        {:ok, context}
      end

      then_ "the dashboard remains unchanged, already showing the default template", context do
        refute has_element?(context.view, "[data-role='reset-dashboard']"),
               "Expected no reset action for a canned dashboard -- confirming the feature doesn't exist"

        flunk(
          "There is no reset action to exercise: canned dashboards have no reset control at " <>
            "all, so there's nothing to confirm is a no-op when uncustomized."
        )
      end
    end
  end
end
