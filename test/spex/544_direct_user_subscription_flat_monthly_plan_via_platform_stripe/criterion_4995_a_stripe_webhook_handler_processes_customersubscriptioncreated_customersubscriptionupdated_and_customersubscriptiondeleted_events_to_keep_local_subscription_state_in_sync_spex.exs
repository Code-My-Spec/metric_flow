defmodule MetricFlowSpex.StripeWebhookHandlerProcessesSubscriptionEventsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "A Stripe webhook handler processes subscription lifecycle events" do
    scenario "webhook endpoint accepts a subscription.created event" do
      given_ "a webhook payload for subscription.created", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "data" => %{
              "object" => %{
                "id" => "sub_test123",
                "customer" => "cus_test123",
                "status" => "active",
                "items" => %{"data" => [%{"price" => %{"id" => "price_test123"}}]},
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the webhook endpoint receives the event", context do
        conn =
          Phoenix.ConnTest.build_conn()
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Plug.Conn.put_req_header("stripe-signature", "test_signature")
          |> Phoenix.ConnTest.post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint returns a success status", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
