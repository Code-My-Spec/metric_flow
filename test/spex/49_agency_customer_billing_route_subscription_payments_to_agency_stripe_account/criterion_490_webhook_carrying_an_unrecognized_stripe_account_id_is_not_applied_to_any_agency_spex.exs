defmodule MetricFlowSpex.WebhookCarryingAnUnrecognizedStripeAccountIdIsNotAppliedToAnyAgencySpex do
  use MetricFlowSpex.Case

  spex "Webhook carrying an unrecognized stripe_account_id is not applied to any agency", criterion: 490 do
    scenario "a webhook event arrives with a stripe_account_id that matches no agency" do
      when_ "the event is posted with an unrecognized connected account", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_unrecognized_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "account" => "acct_unrecognized_#{System.unique_integer([:positive])}",
            "data" => %{
              "object" => %{
                "id" => "sub_unrecognized_#{System.unique_integer([:positive])}",
                "customer" => "cus_unrecognized_#{System.unique_integer([:positive])}",
                "status" => "active",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
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

      then_ "the event is rejected rather than guessed onto any agency", context do
        assert context.response.status == 400
        assert Jason.decode!(context.response.resp_body)["error"] =~ "unrecognized"
        {:ok, context}
      end
    end
  end
end
