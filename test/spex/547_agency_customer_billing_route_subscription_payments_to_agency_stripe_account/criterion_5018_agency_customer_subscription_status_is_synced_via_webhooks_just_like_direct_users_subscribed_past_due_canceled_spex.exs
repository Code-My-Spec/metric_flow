defmodule MetricFlowSpex.AgencySubscriptionStatusSyncedViaWebhooksSpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "Agency customer subscription status is synced via webhooks" do
    scenario "subscription.updated webhook arrives for an agency customer" do
      when_ "a subscription updated event is sent for an agency customer", context do
        event_id = "evt_agency_update_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.updated",
            "account" => "acct_agency_stripe_123",
            "data" => %{
              "object" => %{
                "id" => "sub_agency_abc",
                "customer" => "cus_agency_abc",
                "status" => "past_due",
                "items" => %{"data" => [%{"price" => %{"id" => "price_agency_plan"}}]},
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

        {:ok, Map.merge(context, %{response: conn, event_id: event_id})}
      end

      then_ "the webhook endpoint returns a successful response", context do
        assert context.response.status in [200, 202]
        :ok
      end
    end
  end
end
