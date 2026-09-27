defmodule MetricFlowSpex.CheckoutStartsFromEitherEntryPointSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository

  spex "Checkout starts from either entry point" do
    scenario "a direct user viewing the paywall modal clicks subscribe" do
      given_(:user_logged_in_as_owner)

      given_ "a platform plan exists", context do
        {:ok, plan} =
          BillingRepository.create_plan(%{
            name: "MetricFlow Pro",
            price_cents: 4999,
            currency: "usd",
            billing_interval: :monthly,
            stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, plan: plan})}
      end

      when_ "they click subscribe", context do
        html =
          context.view
          |> element("[data-role=subscribe-button]")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "Stripe Checkout is initiated for the flat monthly plan", context do
        refute context.html =~ "Please select a plan"
        {:ok, context}
      end
    end

    scenario "a direct user viewing account settings clicks subscribe" do
      given_(:user_logged_in_as_owner)

      given_ "a platform plan exists and the user is viewing account settings", context do
        {:ok, plan} =
          BillingRepository.create_plan(%{
            name: "MetricFlow Pro",
            price_cents: 4999,
            currency: "usd",
            billing_interval: :monthly,
            stripe_price_id: "price_test_#{System.unique_integer([:positive])}"
          })

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.merge(context, %{view: view, plan: plan})}
      end

      when_ "they click subscribe from account settings", context do
        html =
          context.view
          |> element("[data-role=subscribe-button]")
          |> render_click()

        {:ok, Map.put(context, :html, html)}
      end

      then_ "Stripe Checkout is initiated for the flat monthly plan", context do
        refute context.html =~ "Please select a plan"
        {:ok, context}
      end
    end
  end
end
