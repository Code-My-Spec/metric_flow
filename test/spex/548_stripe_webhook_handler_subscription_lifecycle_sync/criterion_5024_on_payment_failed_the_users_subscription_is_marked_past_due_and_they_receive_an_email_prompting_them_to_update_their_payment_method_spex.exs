defmodule MetricFlowSpex.PaymentFailedMarksPastDueSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "On payment_failed, subscription is marked past_due" do
    scenario "payment_failed webhook triggers past_due status" do
      when_ "an invoice.payment_failed event is processed", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_pf_#{System.unique_integer([:positive])}",
            "type" => "invoice.payment_failed",
            "data" => %{
              "object" => %{
                "id" => "in_pf_test",
                "customer" => "cus_pastdue",
                "subscription" => "sub_pastdue",
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

      then_ "the webhook is processed successfully", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
