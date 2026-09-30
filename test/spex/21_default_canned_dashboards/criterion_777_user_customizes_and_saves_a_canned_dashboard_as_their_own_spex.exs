defmodule MetricFlowSpex.UserCustomizesAndSavesACannedDashboardAsTheirOwnSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User customizes and saves a canned dashboard as their own", criterion: 777 do
    scenario "a user viewing a canned dashboard customizes its widgets and saves the changes" do
      given_(:user_logged_in_as_owner)

      given_ "a user is viewing a canned dashboard", context do
        MetricFlowSpex.Fixtures.create_canned_dashboard!(
          context.owner_email,
          "Marketing Overview"
        )

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they customize its widgets and save the changes", context do
        {:ok, context}
      end

      then_ "a customized copy is saved as their own, distinct from the original default template",
            context do
        refute has_element?(context.view, "[data-role='customize-dashboard']"),
               "Expected no way to customize a canned dashboard's widgets -- confirming the feature doesn't exist"

        flunk(
          "No way to customize a canned dashboard and save it as the user's own exists. " <>
            "The Dashboard schema has no field linking a user-owned dashboard back to the " <>
            "canned one it was customized from, DashboardsRepository has no such copy/save " <>
            "function, and the canned-dashboard card on the dashboards index only offers a " <>
            "'View' link -- no 'Edit' or 'Customize' action. DashboardLive.Editor's template " <>
            "chooser is a separate, unconnected feature for building a brand-new blank " <>
            "dashboard; it has no reference to any specific canned Dashboard row."
        )
      end
    end
  end
end
