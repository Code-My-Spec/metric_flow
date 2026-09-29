defmodule MetricFlowSpex.ExistingAgencyCustomerKeepsAccessWhenTheAgencysStripeAccountDisconnectsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Existing agency customer keeps access when the agency's Stripe account disconnects", criterion: 492 do
    scenario "a customer already subscribed retains their subscription record when the agency disconnects Stripe" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "a customer already subscribes through the agency's Stripe account", context do
        subscription =
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok, Map.put(context, :subscription_id, subscription.id)}
      end

      given_ :owner_has_stripe_connect

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin disconnects Stripe", context do
        context.view |> element("[data-role=disconnect-stripe]") |> render_click()
        {:ok, context}
      end

      then_ "the customer's subscription record still exists rather than being deleted outright", context do
        status = MetricFlowSpex.Fixtures.subscription_status!(context.subscription_id)
        assert is_atom(status)
        {:ok, context}
      end
    end
  end
end
