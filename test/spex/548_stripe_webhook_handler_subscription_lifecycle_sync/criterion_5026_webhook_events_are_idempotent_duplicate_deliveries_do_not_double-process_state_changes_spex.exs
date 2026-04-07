defmodule MetricFlowSpex.WebhookEventsAreIdempotentSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "Webhook events are idempotent" do
    scenario "sending the same event twice returns success both times" do
      given_ "a webhook event with a fixed event ID", context do
        event_id = "evt_idempotent_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_idempotent",
                "customer" => "cus_idempotent",
                "status" => "active",
                "items" => %{"data" => [%{"price" => %{"id" => "price_test"}}]},
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the same event is sent twice", context do
        first =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        second =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both requests return success", context do
        assert context.first.status in [200, 202]
        assert context.second.status in [200, 202]
        :ok
      end
    end
  end
end
