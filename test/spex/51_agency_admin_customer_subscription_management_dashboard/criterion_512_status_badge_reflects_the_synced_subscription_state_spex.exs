defmodule MetricFlowSpex.StatusBadgeReflectsTheSyncedSubscriptionStateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Status badge reflects the synced subscription state", criterion: 512 do
    scenario "Jordan's subscription status changes from active to past_due via a Stripe webhook" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "Jordan has an active subscription under Acme Agency", context do
        subscription =
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok, Map.put(context, :jordan_subscription, subscription)}
      end

      when_ "Jordan's subscription status changes from active to past_due via a Stripe webhook", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_status_sync_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "data" => %{
              "object" => %{
                "id" => context.jordan_subscription.stripe_subscription_id,
                "customer" => context.jordan_subscription.stripe_customer_id,
                "status" => "past_due",
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

        {:ok, Map.put(context, :webhook_response, conn)}
      end

      then_ "Jordan's status badge shows past_due, reflecting the synced state", context do
        assert context.webhook_response.status in [200, 202]

        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        html = render(view)

        assert html =~ "Past due",
               "Expected Jordan's status badge to show past_due after the sync. Got: #{html}"

        {:ok, context}
      end
    end
  end
end
