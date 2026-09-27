defmodule MetricFlowSpex.WebhookWithAnInvalidSignatureIsRejectedSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Users.Scope

  spex "Webhook with an invalid signature is rejected" do
    scenario "a webhook with a bad signature does not change the account's subscription" do
      given_(:user_logged_in_as_owner)

      given_ "the account has an active subscription in Stripe", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(user)
        account_id = MetricFlow.Accounts.get_personal_account_id(scope)
        subscription_id = "sub_badsig_#{System.unique_integer([:positive])}"

        {:ok, _subscription} =
          BillingRepository.upsert_subscription(%{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: "cus_badsig_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, Map.put(context, :subscription_id, subscription_id)}
      end

      when_ "a webhook with an invalid signature attempts to cancel the subscription", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.deleted",
            "data" => %{
              "object" => %{
                "id" => context.subscription_id,
                "customer" => "cus_badsig",
                "status" => "canceled",
                "canceled_at" => 1_700_100_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header(
            "stripe-signature",
            "t=1700000000,v1=" <> String.duplicate("0", 64)
          )
          |> Phoenix.ConnTest.post("/billing/webhooks", payload)

        {:ok, Map.put(context, :webhook_response, conn)}
      end

      then_ "the webhook is rejected", context do
        assert context.webhook_response.status == 400
        {:ok, context}
      end

      then_ "the account's subscription is unchanged", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        html = render(view)
        assert html =~ "Active"
        refute html =~ "Cancelled"
        {:ok, context}
      end
    end
  end
end
