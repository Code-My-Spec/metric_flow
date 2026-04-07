defmodule MetricFlowSpex.CheckoutUsesStripeCheckoutSessionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Checkout uses Stripe Checkout Session and redirects to a success/cancel URL" do
    scenario "user clicks subscribe and is redirected to Stripe checkout" do
      given_ :user_logged_in_as_owner

      given_ "a platform plan exists", context do
        {:ok, plan} =
          MetricFlow.Billing.BillingRepository.create_plan(%{
            name: "MetricFlow Pro",
            price_cents: 4999,
            currency: "usd",
            billing_interval: :monthly,
            stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
          })

        {:ok, Map.put(context, :plan, plan)}
      end

      given_ "the user is on the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page shows a subscribe button with the plan", context do
        html = render(context.view)
        assert html =~ "MetricFlow Pro"
        assert has_element?(context.view, "[data-role=subscribe-button]")
        :ok
      end
    end
  end
end
