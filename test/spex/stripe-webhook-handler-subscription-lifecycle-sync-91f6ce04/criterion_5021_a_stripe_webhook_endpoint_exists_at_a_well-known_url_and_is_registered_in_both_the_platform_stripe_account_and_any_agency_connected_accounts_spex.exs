defmodule MetricFlowSpex.StripeWebhookEndpointExistsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "A Stripe webhook endpoint exists at a well-known URL" do
    scenario "POST to /billing/webhooks returns a valid response" do
      given_ "a minimal webhook payload", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "ping",
            "data" => %{"object" => %{}}
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the payload is sent to the webhook endpoint", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint responds without a 404", context do
        refute context.response.status == 404
        :ok
      end
    end
  end
end
