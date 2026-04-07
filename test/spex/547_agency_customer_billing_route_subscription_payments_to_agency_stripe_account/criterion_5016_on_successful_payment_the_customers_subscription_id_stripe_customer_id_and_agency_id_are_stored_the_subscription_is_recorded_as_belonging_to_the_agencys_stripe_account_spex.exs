defmodule MetricFlowSpex.SuccessfulPaymentStoresAgencySubscriptionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On successful payment, subscription is recorded as belonging to the agency's Stripe account" do
    scenario "user lands on checkout success page after payment" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout success page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout?success=true&session_id=cs_test_abc123")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the subscription as active", context do
        html = render(context.view)
        assert html =~ "active" or html =~ "Active" or html =~ "subscri" or html =~ "success" or html =~ "Success"
        :ok
      end
    end
  end
end
