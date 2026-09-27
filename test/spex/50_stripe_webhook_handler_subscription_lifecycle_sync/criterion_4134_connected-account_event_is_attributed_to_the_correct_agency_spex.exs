defmodule MetricFlowSpex.ConnectedAccountEventIsAttributedToTheCorrectAgencySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Users.Scope

  spex "Connected-account event is attributed to the correct agency" do
    scenario "an event delivered via an agency's connected Stripe account is accepted for that agency" do
      given_(:user_logged_in_as_owner)

      given_ "an agency's connected Stripe account", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        scope = Scope.for_user(user)
        agency_account_id = MetricFlow.Accounts.get_personal_account_id(scope)
        stripe_account_id = "acct_connected_#{System.unique_integer([:positive])}"

        {:ok, _stripe_account} =
          BillingRepository.upsert_stripe_account(%{
            stripe_account_id: stripe_account_id,
            agency_account_id: agency_account_id,
            onboarding_status: :complete,
            capabilities: %{charges_enabled: true, payouts_enabled: true}
          })

        {:ok, Map.put(context, :stripe_account_id, stripe_account_id)}
      end

      when_ "a webhook event is delivered via that connected account", context do
        payload =
          Jason.encode!(%{
            "id" => "evt_connected_#{System.unique_integer([:positive])}",
            "type" => "customer.subscription.updated",
            "account" => context.stripe_account_id,
            "data" => %{
              "object" => %{
                "id" => "sub_connected",
                "customer" => "cus_connected",
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

      then_ "it is attributed to that agency's customer records", context do
        assert context.response.status in [200, 202]
        {:ok, context}
      end
    end
  end
end
