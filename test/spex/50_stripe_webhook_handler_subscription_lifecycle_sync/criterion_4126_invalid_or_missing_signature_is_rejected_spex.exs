defmodule MetricFlowSpex.InvalidOrMissingSignatureIsRejectedSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Invalid or missing signature is rejected" do
    scenario "a webhook event with an invalid Stripe-Signature header is rejected" do
      given_ "a webhook event with an invalid Stripe-Signature header", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_invalid_sig",
                "customer" => "cus_invalid_sig",
                "status" => "active"
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the event is received", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "t=1700000000,v1=" <> String.duplicate("0", 64))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "it is rejected and not processed", context do
        assert context.response.status == 400
        {:ok, context}
      end
    end
  end
end
