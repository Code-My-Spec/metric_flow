defmodule MetricFlowSpex.CancellationDowngradesUserAtPeriodEndSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository

  spex "Cancellation downgrades user at period end" do
    scenario "a subscription cancelled via customer.subscription.deleted downgrades the user once the period ends" do
      given_(:user_logged_in_as_owner)

      given_ "an active subscription whose billing period has now ended", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)
        subscription_id = "sub_cancel_period_#{System.unique_integer([:positive])}"

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: "cus_cancel_period_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.utc_now()
          })

        {:ok, Map.put(context, :subscription_id, subscription_id)}
      end

      when_ "a subscription cancelled via customer.subscription.deleted is delivered", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.deleted",
            "data" => %{
              "object" => %{
                "id" => context.subscription_id,
                "customer" => "cus_cancel_period",
                "status" => "canceled",
                "canceled_at" => System.system_time(:second),
                "current_period_end" => System.system_time(:second)
              }
            }
          })

        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(payload))
          |> post("/billing/webhooks", payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the webhook is accepted", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end

      then_ "the user is downgraded to free", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Subscribe" or html =~ "No plans available"
        refute html =~ "Current Subscription"
        {:ok, context}
      end
    end
  end
end
