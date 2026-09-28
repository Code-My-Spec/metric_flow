defmodule MetricFlowSpex.UnrecognizedEventTypeIsAcknowledgedAndIgnoredSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Unrecognized event type is acknowledged and ignored", criterion: 452 do
    scenario "an event type outside the minimum processed set is acknowledged" do
      given_ "a webhook event of a type outside the minimum processed set", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "account.application.deauthorized",
            "data" => %{"object" => %{}}
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the webhook is received", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header(
            "stripe-signature",
            MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload)
          )
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "it is acknowledged and ignored without error", context do
        assert context.response.status in [200, 202]
        assert json_response(context.response, context.response.status)["ignored"] == true
        {:ok, context}
      end
    end
  end
end
