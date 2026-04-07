defmodule MetricFlowSpex.WebhookProcessesSubscriptionEventsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "The handler processes subscription lifecycle events" do
    scenario "subscription.created event is accepted" do
      when_ "a subscription.created event is sent", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_created_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "data" => %{
              "object" => %{
                "id" => "sub_test_created",
                "customer" => "cus_test",
                "status" => "active",
                "items" => %{"data" => [%{"price" => %{"id" => "price_test"}}]},
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
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

      then_ "the endpoint returns 200", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end

    scenario "invoice.payment_failed event is accepted" do
      when_ "an invoice.payment_failed event is sent", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_failed_#{System.unique_integer([:positive])}",
            "type" => "invoice.payment_failed",
            "data" => %{
              "object" => %{
                "id" => "in_test_failed",
                "customer" => "cus_test",
                "subscription" => "sub_test",
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

      then_ "the endpoint returns 200", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
