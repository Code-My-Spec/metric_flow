defmodule MetricFlowSpex.AgencyWebhookEventsRoutedCorrectlySpex do
  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens

  spex "Webhook events for agency customer subscriptions are routed and processed correctly" do
    scenario "webhook event arrives with agency Stripe account ID in the payload" do
      when_ "a subscription event is sent for an agency customer", context do
        event_id = "evt_agency_#{System.unique_integer([:positive])}"

        payload =
          Jason.encode!(%{
            "id" => event_id,
            "type" => "customer.subscription.created",
            "account" => "acct_agency_stripe_123",
            "data" => %{
              "object" => %{
                "id" => "sub_agency_abc",
                "customer" => "cus_agency_abc",
                "status" => "active",
                "items" => %{"data" => [%{"price" => %{"id" => "price_agency_plan"}}]},
                "current_period_start" => 1_700_000_000,
                "current_period_end" => 1_702_592_000
              }
            }
          })

        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> put_req_header("stripe-signature", "test_signature")
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
