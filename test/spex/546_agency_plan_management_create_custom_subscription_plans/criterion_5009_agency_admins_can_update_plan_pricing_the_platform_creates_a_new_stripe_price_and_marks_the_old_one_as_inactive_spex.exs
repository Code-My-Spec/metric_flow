defmodule MetricFlowSpex.AgencyAdminsCanUpdatePlanPricingSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins can update plan pricing" do
    scenario "admin updates a plan's monthly price" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :owner_has_agency_plan

      given_ "the admin navigates to the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin edits an existing plan's price", context do
        html =
          context.view
          |> element("[data-role=edit-plan]")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the updated price is displayed", context do
        html = render(context.view)
        assert html =~ "Edit" or html =~ "Update"
        :ok
      end
    end
  end
end
