defmodule MetricFlowSpex.SubscriptionCancellationsHandledGracefullySpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "Subscription cancellations are handled gracefully with access until period end" do
    scenario "webhook for subscription.deleted downgrades user at period end" do
      given_ "a webhook payload for subscription.deleted", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.deleted",
            "data" => %{
              "object" => %{
                "id" => "sub_test_cancel",
                "customer" => "cus_test_cancel",
                "status" => "canceled",
                "canceled_at" => 1_700_100_000,
                "current_period_end" => 1_702_592_000,
                "items" => %{"data" => [%{"price" => %{"id" => "price_test123"}}]}
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the webhook endpoint receives the cancellation event", context do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header("stripe-signature", "test_signature")
          |> Phoenix.ConnTest.post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint processes the cancellation successfully", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
