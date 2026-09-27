defmodule MetricFlowSpex.PlanIsVisibleOnThePaywallSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository

  spex "Plan is visible on the paywall" do
    scenario "a direct user views the paywall and sees the configured flat monthly plan" do
      given_(:user_logged_in_as_owner)

      given_ "the flat monthly plan is configured with a name, price, and Stripe Price ID", context do
        {:ok, plan} =
          BillingRepository.create_plan(%{
            name: "MetricFlow Pro",
            price_cents: 4999,
            currency: "usd",
            billing_interval: :monthly,
            stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
          })

        {:ok, Map.put(context, :plan, plan)}
      end

      when_ "a direct user views the paywall", context do
        {:ok, view, html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "they see that plan available to subscribe to", context do
        assert context.html =~ "MetricFlow Pro"
        assert context.html =~ "$"
        assert has_element?(context.view, "[data-role=subscribe-button]")
        {:ok, context}
      end
    end
  end
end
