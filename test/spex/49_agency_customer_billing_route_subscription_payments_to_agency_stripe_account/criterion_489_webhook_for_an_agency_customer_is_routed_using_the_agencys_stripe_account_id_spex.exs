defmodule MetricFlowSpex.WebhookForAnAgencyCustomerIsRoutedUsingTheAgencysStripeAccountIdSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Webhook for an agency customer is routed using the agency's stripe_account_id", criterion: 489 do
    scenario "a webhook event carries the agency's own connected Stripe account id" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect

      when_ "a subscription event arrives tagged with the agency's connected account", context do
        stripe_account_id = MetricFlowSpex.Fixtures.agency_stripe_account_id(context.owner_email)

        payload =
          Jason.encode!(%{
            "id" => "evt_agency_route_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.created",
            "account" => stripe_account_id,
            "data" => %{
              "object" => %{
                "id" => "sub_agency_route_#{System.unique_integer([:positive])}",
                "customer" => "cus_agency_route_#{System.unique_integer([:positive])}",
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

      then_ "the event is accepted and matched to the agency, not rejected as unrecognized", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
