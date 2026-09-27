defmodule MetricFlowSpex.PaymentFailureMarksSubscriptionPastDueAndNotifiesTheUserSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository

  spex "Payment failure marks subscription past_due and notifies the user" do
    scenario "invoice.payment_failed marks the subscription past_due and emails the user" do
      given_(:user_logged_in_as_owner)

      given_ "an active subscription", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)
        subscription_id = "sub_pay_fail_#{System.unique_integer([:positive])}"

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: "cus_pay_fail_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, Map.put(context, :subscription_id, subscription_id)}
      end

      when_ "invoice.payment_failed is received", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "invoice.payment_failed",
            "data" => %{
              "object" => %{
                "id" => "in_pay_fail",
                "customer" => "cus_pay_fail",
                "subscription" => context.subscription_id,
                "status" => "open"
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

      then_ "the subscription is marked past_due", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Past due"
        {:ok, context}
      end

      then_ "the user is emailed to update their payment method", context do
        assert_receive {:email, _email}, 1000
        {:ok, context}
      end
    end
  end
end
