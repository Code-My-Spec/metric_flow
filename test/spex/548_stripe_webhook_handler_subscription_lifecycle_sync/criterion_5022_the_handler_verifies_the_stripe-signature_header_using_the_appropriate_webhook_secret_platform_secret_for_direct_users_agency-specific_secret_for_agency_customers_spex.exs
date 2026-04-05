defmodule MetricFlowSpex.WebhookVerifiesStripeSignatureSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "The handler verifies the Stripe-Signature header" do
    scenario "request without Stripe-Signature header is rejected" do
      given_ "a webhook payload with no signature header", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "data" => %{"object" => %{"id" => "sub_test"}}
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the payload is sent without a Stripe-Signature header", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint returns a 400 error", context do
        assert context.response.status == 400
        :ok
      end
    end
  end
end
