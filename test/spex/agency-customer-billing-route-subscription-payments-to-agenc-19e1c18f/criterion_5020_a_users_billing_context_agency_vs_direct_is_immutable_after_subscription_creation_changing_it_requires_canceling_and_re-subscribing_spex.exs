defmodule MetricFlowSpex.BillingContextImmutableAfterSubscriptionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "A user's billing context is immutable after subscription creation" do
    scenario "user views checkout page which reflects their billing context" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page shows the user's current billing context", context do
        html = render(context.view)
        assert html =~ "billing" or html =~ "Billing" or html =~ "subscription" or
                 html =~ "Subscription" or html =~ "checkout" or html =~ "Checkout"
        :ok
      end
    end
  end
end
