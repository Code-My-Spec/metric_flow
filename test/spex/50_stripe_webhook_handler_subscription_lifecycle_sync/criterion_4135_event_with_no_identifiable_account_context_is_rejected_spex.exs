defmodule MetricFlowSpex.EventWithNoIdentifiableAccountContextIsRejectedSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Event with no identifiable account context is rejected" do
    scenario "an event referencing an unrecognized connected account is rejected rather than guessed" do
      given_ "a webhook event with no identifiable platform or connected-account context", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_no_context_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "account" => "acct_unregistered_#{System.unique_integer([:positive])}",
            "data" => %{
              "object" => %{
                "id" => "sub_no_context",
                "customer" => "cus_no_context",
                "status" => "active"
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "it is received", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "it is rejected rather than guessed", context do
        assert context.response.status == 400
        {:ok, context}
      end
    end
  end
end
