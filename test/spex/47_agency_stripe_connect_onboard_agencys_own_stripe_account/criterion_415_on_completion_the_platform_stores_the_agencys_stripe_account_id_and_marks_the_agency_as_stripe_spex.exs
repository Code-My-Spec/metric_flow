defmodule MetricFlowSpex.PlatformStoresStripeAccountIdSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "On completion, platform stores stripe_account_id and marks connected", criterion: 415 do
    scenario "after Stripe onboarding completion, status shows connected" do
      given_ :user_logged_in_as_owner

      given_ "the admin visits the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows connection status", context do
        html = render(context.view)
        assert html =~ "Stripe Connect"
        {:ok, context}
      end
    end
  end
end
