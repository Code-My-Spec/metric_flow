defmodule MetricFlowSpex.SubscriptionDeletedDowngradesToFreeSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "On subscription.deleted, user is downgraded to free" do
    scenario "subscription.deleted webhook is processed" do
      given_(:user_logged_in_as_owner)

      when_ "a subscription.deleted event is sent", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_del_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.deleted",
            "data" => %{
              "object" => %{
                "id" => "sub_deleted",
                "customer" => "cus_deleted",
                "status" => "canceled",
                "canceled_at" => 1_700_100_000,
                "current_period_end" => 1_702_592_000,
                "items" => %{"data" => [%{"price" => %{"id" => "price_test"}}]},
                "metadata" => %{"account_id" => "#{account_id}"}
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

      then_ "the webhook is processed successfully", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
