defmodule MetricFlowSpex.AgencySubscriptionStatusSyncedViaWebhooksSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency customer subscription status is synced via webhooks", criterion: 432 do
    scenario "subscription.updated webhook arrives for an agency customer" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect

      when_ "a subscription updated event is sent for an agency customer's existing subscription", context do
        stripe_account_id = MetricFlowSpex.Fixtures.agency_stripe_account_id(context.owner_email)
        sub_id = "sub_agency_abc"

        created_payload =
          Jason.encode!(%{
            "id" => "evt_agency_create_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "account" => stripe_account_id,
            "data" => %{
              "object" => %{
                "id" => sub_id,
                "customer" => "cus_agency_abc",
                "status" => "active",
                "items" => %{"data" => [%{"price" => %{"id" => "price_agency_plan"}}]},
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", MetricFlowSpex.SharedGivens.sign_webhook_payload(created_payload))
        |> post("/billing/webhooks", created_payload)

        event_id = "evt_agency_update_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.updated",
            "account" => stripe_account_id,
            "data" => %{
              "object" => %{
                "id" => sub_id,
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
        {:ok, context}
      end
    end
  end
end
