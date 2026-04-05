defmodule MetricFlowSpex.AgencyAdminCanInitiateStripeConnectSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency admin can navigate to Stripe Connect page and initiate onboarding" do
    scenario "admin visits Stripe Connect page" do
      given_ :user_logged_in_as_owner

      given_ "the admin navigates to the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays Stripe Connect onboarding options", context do
        html = render(context.view)
        assert html =~ "Stripe Connect"
        :ok
      end
    end
  end
end
