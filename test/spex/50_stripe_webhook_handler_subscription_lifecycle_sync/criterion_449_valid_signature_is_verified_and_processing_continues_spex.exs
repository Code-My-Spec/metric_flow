defmodule MetricFlowSpex.ValidSignatureIsVerifiedAndProcessingContinuesSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Valid signature is verified and processing continues", criterion: 449 do
    scenario "a webhook event with a valid Stripe-Signature for its account is accepted" do
      given_(:user_logged_in_as_owner)

      given_ "a webhook event with a valid Stripe-Signature for its account", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_test_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_valid_sig",
                "customer" => "cus_valid_sig",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => "#{account_id}"}
              }
            }
          })

        {:ok, Map.put(context, :payload, payload)}
      end

      when_ "the event is received", context do
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

      then_ "it is verified and processing continues", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
