defmodule MetricFlowSpex.SuccessfulPaymentRedirectsToSuccessUrlSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Successful payment redirects to the success URL" do
    scenario "a user's browser returns from a completed Stripe Checkout payment" do
      given_(:user_logged_in_as_owner)

      when_ "the browser lands on the checkout page's Stripe success URL", context do
        session_id = "cs_test_#{System.unique_integer([:positive])}"

        {:ok, _view, html} =
          live(context.owner_conn, "/app/subscriptions/checkout?success=true&session_id=#{session_id}")

        {:ok, Map.put(context, :html, html)}
      end

      then_ "the success URL resolves to the checkout page", context do
        assert context.html =~ "Choose Your Plan"
        {:ok, context}
      end
    end
  end
end
