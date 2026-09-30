defmodule MetricFlowSpex.Criterion165UserCanResetToDefaultTemplateIfTheyHaveCustomizedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User can reset to default template if they have customized", criterion: 165 do
    scenario "a user who has customized a canned dashboard chooses to reset it" do
      given_(:user_logged_in_as_owner)

      given_ "a user has customized a canned dashboard", context do
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

      then_ "the dashboard reverts to the current default template, discarding their customizations",
            context do
        refute has_element?(context.view, "[data-role='reset-dashboard']"),
               "Expected no reset action for a canned dashboard -- confirming the feature doesn't exist"

        flunk(
          "No way to reset a customized dashboard to its current default template exists. " <>
            "There is no 'customized dashboard' concept to reset in the first place -- the " <>
            "Dashboard schema has no field linking a dashboard back to a canned original, and " <>
            "DashboardsRepository has no reset function of any kind."
        )
      end
    end
  end
end
