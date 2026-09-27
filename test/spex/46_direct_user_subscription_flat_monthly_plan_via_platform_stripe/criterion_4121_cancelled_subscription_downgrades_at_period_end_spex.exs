defmodule MetricFlowSpex.CancelledSubscriptionDowngradesAtPeriodEndSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  spex "Cancelled subscription downgrades at period end" do
    scenario "the user is downgraded to free once the billing period Stripe reported has ended" do
      given_(:user_logged_in_as_owner)

      given_ "the user's subscription was cancelled and its billing period has now ended", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)
        subscription_id = "sub_period_end_#{System.unique_integer([:positive])}"

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: "cus_period_end_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.utc_now()
          })

        {:ok, Map.put(context, :subscription_id, subscription_id)}
      end

      when_ "Stripe sends the subscription.deleted event for the ended period", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.deleted",
            "data" => %{
              "object" => %{
                "id" => context.subscription_id,
                "customer" => "cus_period_end",
                "status" => "canceled",
                "canceled_at" => System.system_time(:second),
                "current_period_end" => System.system_time(:second)
              }
            }
          })

        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header(
            "stripe-signature",
            MetricFlowSpex.SharedGivens.sign_webhook_payload(payload)
          )
          |> Phoenix.ConnTest.post("/billing/webhooks", payload)

        {:ok, Map.put(context, :webhook_response, conn)}
      end

      then_ "the webhook is accepted", context do
        assert context.webhook_response.status in [200, 202]
        {:ok, context}
      end

      then_ "the user is downgraded to the free plan", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Subscribe" or html =~ "No plans available"
        refute html =~ "Current Subscription"
        {:ok, context}
      end
    end
  end
end
