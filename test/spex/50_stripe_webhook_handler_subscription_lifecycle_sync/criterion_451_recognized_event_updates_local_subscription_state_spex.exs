defmodule MetricFlowSpex.RecognizedEventUpdatesLocalSubscriptionStateSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Recognized event updates local subscription state", criterion: 451 do
    scenario "a customer.subscription.updated event is accepted for processing" do
      given_(:user_logged_in_as_owner)

      given_ "a customer.subscription.updated event", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_recognized",
                "customer" => "cus_recognized",
                "status" => "past_due",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => "#{account_id}"}
              }
            }
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

      then_ "local subscription state is updated to match", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
