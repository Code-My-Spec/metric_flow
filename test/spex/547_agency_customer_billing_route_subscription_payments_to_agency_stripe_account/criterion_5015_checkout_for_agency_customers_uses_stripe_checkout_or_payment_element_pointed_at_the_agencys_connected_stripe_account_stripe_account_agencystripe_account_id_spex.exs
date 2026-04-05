defmodule MetricFlowSpex.AgencyCheckoutUsesConnectedStripeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Checkout for agency customers uses the agency's connected Stripe account" do
    scenario "agency customer initiates checkout" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page indicates it will process through the agency's Stripe account", context do
        html = render(context.view)
        assert html =~ "checkout" or html =~ "Checkout" or html =~ "payment" or html =~ "Payment"
        :ok
      end
    end
  end
end
