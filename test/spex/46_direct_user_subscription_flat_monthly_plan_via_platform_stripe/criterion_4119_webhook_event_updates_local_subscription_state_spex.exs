defmodule MetricFlowSpex.WebhookEventUpdatesLocalSubscriptionStateSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Users.Scope

  spex "Webhook event updates local subscription state" do
    scenario "a subscription.updated event changes the account's stored status" do
      given_(:user_logged_in_as_owner)

      given_ "the account has an active subscription in Stripe", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(user)
        account_id = MetricFlow.Accounts.get_personal_account_id(scope)
        subscription_id = "sub_update_#{System.unique_integer([:positive])}"
        customer_id = "cus_update_#{System.unique_integer([:positive])}"

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: customer_id,
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, Map.merge(context, %{subscription_id: subscription_id, customer_id: customer_id})}
      end

      when_ "Stripe sends a customer.subscription.updated event marking the subscription past due", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => context.subscription_id,
                "customer" => context.customer_id,
                "status" => "past_due",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
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

      then_ "the account's checkout page reflects the updated subscription status", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Past due"
        {:ok, context}
      end
    end
  end
end
