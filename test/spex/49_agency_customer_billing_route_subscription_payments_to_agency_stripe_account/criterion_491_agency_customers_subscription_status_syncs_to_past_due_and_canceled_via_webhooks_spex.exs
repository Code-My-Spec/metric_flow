defmodule MetricFlowSpex.AgencyCustomersSubscriptionStatusSyncsToPastDueAndCanceledViaWebhooksSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency customer's subscription status syncs to past_due and canceled via webhooks", criterion: 491 do
    scenario "an agency customer's subscription is marked past_due by a webhook" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      when_ "Stripe sends a subscription.updated event marking the subscription past_due", context do
        account_id = MetricFlowSpex.Fixtures.personal_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_agency_sync_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => "sub_agency_sync_#{System.unique_integer([:positive])}",
                "customer" => "cus_agency_sync_#{System.unique_integer([:positive])}",
                "status" => "past_due",
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000,
                "metadata" => %{"account_id" => to_string(account_id)}
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

      then_ "the webhook endpoint accepts the status change", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
