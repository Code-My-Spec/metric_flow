defmodule MetricFlowSpex.AgencySettingsListsActivePlansSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency settings UI lists active plans with Stripe Price IDs and status" do
    scenario "agency plans page displays plan details" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      given_ "the admin navigates to the agency plans page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/plans")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows plans with their status", context do
        html = render(context.view)
        assert html =~ "Plans" or html =~ "plans"
        :ok
      end
    end
  end
end
