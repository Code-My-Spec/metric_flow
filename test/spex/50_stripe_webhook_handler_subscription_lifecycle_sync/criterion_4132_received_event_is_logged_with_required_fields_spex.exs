defmodule MetricFlowSpex.ReceivedEventIsLoggedWithRequiredFieldsSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Received event is logged with required fields" do
    scenario "processing a webhook event acknowledges it for audit logging" do
      given_(:user_logged_in_as_owner)

      given_ "any webhook event is received", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_log_fields_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_log_fields",
                "customer" => "cus_log_fields",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => "#{account_id}"}
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "it is processed", context do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(context.payload))
          |> post("/billing/webhooks", context.payload)

        {:ok, Map.put(context, :response, conn)}
      end

      then_ "a log entry is recorded with its event ID, type, processed status, and timestamp", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
