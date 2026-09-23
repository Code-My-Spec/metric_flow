defmodule MetricFlowSpex.AgencyAdminsCannotSeeOtherAgenciesDataSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins cannot see or modify other agencies' customer data" do
    scenario "agency admin views subscriptions page which only shows their own agency's data" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect
      given_ :second_user_registered

      when_ "the first admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page does not show the second agency's email", context do
        html = render(context.view)
        refute html =~ context.second_user_email
        :ok
      end
    end
  end
end
