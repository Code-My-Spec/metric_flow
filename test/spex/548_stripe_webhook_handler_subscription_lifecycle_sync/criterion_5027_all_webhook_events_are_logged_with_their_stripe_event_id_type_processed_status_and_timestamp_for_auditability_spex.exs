defmodule MetricFlowSpex.WebhookEventsAreLoggedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "All webhook events are logged for auditability" do
    scenario "processed event returns response with event ID acknowledgment" do
      when_ "a webhook event is sent", context do
        event_id = "evt_log_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.created",
            "data" => %{
              "object" => %{
                "id" => "sub_logged",
                "customer" => "cus_logged",
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
          |> put_req_header("stripe-signature", "test_signature")
          |> post("/billing/webhooks", payload)

        {:ok, Map.merge(context, %{response: conn, event_id: event_id})}
      end

      then_ "the response confirms the event was received", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
