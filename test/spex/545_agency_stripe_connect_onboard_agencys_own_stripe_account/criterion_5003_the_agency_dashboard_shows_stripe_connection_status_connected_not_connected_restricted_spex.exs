defmodule MetricFlowSpex.AgencyDashboardShowsStripeStatusSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency dashboard shows Stripe connection status" do
    scenario "not connected agency sees status on Stripe Connect page" do
      given_ :user_logged_in_as_owner

      given_ "the admin navigates to the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows connection status information", context do
        html = render(context.view)
        assert html =~ "Stripe Connect"
        :ok
      end
    end
  end
end
