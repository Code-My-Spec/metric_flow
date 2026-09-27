defmodule MetricFlowSpex.CancelledOrFailedPaymentRedirectsToCancelUrlSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Cancelled or failed payment redirects to the cancel URL" do
    scenario "a user's browser returns from a cancelled Stripe Checkout attempt" do
      given_(:user_logged_in_as_owner)

      when_ "the browser lands on the checkout page's Stripe cancel URL", context do
        {:ok, _view, html} =
          live(context.owner_conn, "/app/subscriptions/checkout?cancelled=true")

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the cancel URL resolves to the checkout page and the user remains unsubscribed", context do
        assert context.html =~ "Subscribe" or context.html =~ "No plans available"
        refute context.html =~ "Current Subscription"
        {:ok, context}
      end
    end
  end
end
