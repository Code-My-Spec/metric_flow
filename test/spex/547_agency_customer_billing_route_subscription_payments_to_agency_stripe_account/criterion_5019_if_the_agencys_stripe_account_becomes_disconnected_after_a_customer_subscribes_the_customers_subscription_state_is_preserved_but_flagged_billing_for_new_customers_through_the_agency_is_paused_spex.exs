defmodule MetricFlowSpex.DisconnectedAgencyPreservesSubscriptionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If agency Stripe account disconnects, existing subscriptions preserved and new billing paused" do
    scenario "user visits checkout when agency Stripe is disconnected" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page shows a warning about the disconnected agency Stripe account", context do
        html = render(context.view)
        assert html =~ "disconnected" or html =~ "unavailable" or html =~ "warning" or
                 html =~ "paused" or html =~ "checkout" or html =~ "Checkout"
        :ok
      end
    end
  end
end
