defmodule MetricFlowSpex.DuplicateDeliveryOfTheSameEventIsANoOpSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Duplicate delivery of the same event is a no-op", criterion: 455 do
    scenario "redelivering an already-processed event applies no additional state change" do
      given_(:user_logged_in_as_owner)

      given_ "a webhook event that has already been processed", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_dup_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_dup",
                "customer" => "cus_dup",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => "#{account_id}"}
              }
            }
          })

        first =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(payload))
          |> post("/billing/webhooks", payload)

        assert first.status in [200, 202]

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the same event ID is delivered again", context do
        second =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, second)}
      end

      then_ "no additional state change is applied", context do
        assert context.response.status in [200, 202]
        assert json_response(context.response, context.response.status)["duplicate"] == true
        {:ok, context}
      end
    end
  end
end
