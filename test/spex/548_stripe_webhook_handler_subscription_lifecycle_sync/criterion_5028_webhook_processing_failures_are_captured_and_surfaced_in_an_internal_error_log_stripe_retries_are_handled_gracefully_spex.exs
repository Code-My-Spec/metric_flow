defmodule MetricFlowSpex.WebhookFailuresCapturedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "Webhook processing failures are captured gracefully" do
    scenario "malformed payload returns error without crashing" do
      when_ "an invalid JSON payload is sent to the webhook endpoint", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "test_signature")
          |> post("/billing/webhooks", "not valid json")

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint returns a 400 error without crashing", context do
        assert context.response.status in [400, 422]
        :ok
      end
    end

    scenario "unknown event type is handled gracefully" do
      when_ "an unrecognized event type is sent", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_unknown_#{System.unique_integer([:positive])}",
            "type" => "unknown.event.type",
            "data" => %{"object" => %{}}
          })

        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "test_signature")
          |> post("/billing/webhooks", payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "the endpoint returns success without crashing", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
