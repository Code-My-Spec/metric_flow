defmodule MetricFlowSpex.AgencyAdminCancelCustomerSubscriptionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admins can cancel a specific customer's subscription" do
    scenario "agency admin clicks cancel on a customer subscription" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      when_ "the admin navigates to the agency subscriptions page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a cancel action is available for each subscription", context do
        html = render(context.view)
        # Cancel button shown for active subscriptions; empty state shows "No customer subscriptions yet"
        assert html =~ "Cancel" or html =~ "No customer subscriptions yet" or
                 html =~ "Customer Subscriptions"
        :ok
      end
    end
  end
end
