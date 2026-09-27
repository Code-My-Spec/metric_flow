defmodule MetricFlowSpex.AccountIsMarkedSubscribedAfterPaymentSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Users.Scope

  spex "Account is marked subscribed after payment" do
    scenario "a completed checkout session marks the paying account subscribed" do
      given_(:user_logged_in_as_owner)

      given_ "the account that completed Stripe Checkout", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(user)
        account_id = MetricFlow.Accounts.get_personal_account_id(scope)

        {:ok,
         Map.merge(context, %{
           account_id: account_id,
           stripe_customer_id: "cus_pay_#{System.unique_integer([:positive])}",
           stripe_subscription_id: "sub_pay_#{System.unique_integer([:positive])}"
         })}
      end

      when_ "Stripe delivers a customer.subscription.created event for that checkout session", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "data" => %{
              "object" => %{
                "id" => context.stripe_subscription_id,
                "customer" => context.stripe_customer_id,
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => to_string(context.account_id)}
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

      then_ "the account's checkout page shows an active subscription", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Current Subscription"
        assert html =~ "Active"
        {:ok, context}
      end
    end
  end
end
