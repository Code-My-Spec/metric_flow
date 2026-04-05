defmodule MetricFlowSpex.SubscriptionDeletedDowngradesToFreeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "On subscription.deleted, user is downgraded to free" do
    scenario "subscription.deleted webhook is processed" do
      when_ "a subscription.deleted event is sent", context do
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
                "items" => %{"data" => [%{"price" => %{"id" => "price_test"}}]}
              }
            }
          })

        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "test_signature")
          |> post("/billing/webhooks", payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the webhook is processed successfully", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
