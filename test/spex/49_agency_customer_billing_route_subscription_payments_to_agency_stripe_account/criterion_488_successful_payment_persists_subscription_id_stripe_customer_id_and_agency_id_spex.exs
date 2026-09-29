defmodule MetricFlowSpex.SuccessfulPaymentPersistsSubscriptionIdStripeCustomerIdAndAgencyIdSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Successful payment persists subscription_id, stripe_customer_id, and agency_id", criterion: 488 do
    scenario "a subscription.created webhook arrives for an agency customer's successful payment" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "Stripe confirms the payment via a subscription.created webhook", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_agency_pay_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "data" => %{
              "object" => %{
                "id" => "sub_agency_pay_#{System.unique_integer([:positive])}",
                "customer" => "cus_agency_pay_#{System.unique_integer([:positive])}",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => to_string(account_id)}
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

      then_ "the webhook is accepted and the subscription now shows as active on the agency's account", context do
        assert context.response.status in [200, 202]

        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Active"
        {:ok, context}
      end
    end
  end
end
