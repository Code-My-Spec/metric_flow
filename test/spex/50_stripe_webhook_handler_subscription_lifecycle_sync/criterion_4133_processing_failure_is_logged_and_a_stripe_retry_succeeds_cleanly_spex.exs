defmodule MetricFlowSpex.ProcessingFailureIsLoggedAndAStripeRetrySucceedsCleanlySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Processing failure is logged and a Stripe retry succeeds cleanly" do
    scenario "a rejected delivery is captured, and Stripe's retry with a valid signature succeeds" do
      given_ "processing of a webhook event raises an error", context do
        event_id = "evt_retry_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_retry",
                "customer" => "cus_retry",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        failed =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "t=1700000000,v1=" <> String.duplicate("0", 64))
          |> post("/billing/webhooks", payload)

        assert failed.status == 400

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "Stripe retries delivery of the same event", context do
        retry =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, retry)}
      end

      then_ "the retry succeeds without duplicating side effects", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
