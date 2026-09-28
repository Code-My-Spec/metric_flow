defmodule MetricFlowSpex.AgencyAdminsCanDeactivatePlanSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency admins can deactivate a plan", criterion: 424 do
    scenario "admin deactivates an existing plan" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :owner_has_agency_plan

      given_ "the admin navigates to the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin clicks deactivate on a plan", context do
        html =
          context.view
          |> element("[data-role=deactivate-plan]")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the plan is marked as inactive", context do
        html = render(context.view)
        assert html =~ "Inactive" or html =~ "Deactivated" or html =~ "deactivated" or
                 html =~ "Plan deactivated"
        {:ok, context}
      end
    end
  end
end
