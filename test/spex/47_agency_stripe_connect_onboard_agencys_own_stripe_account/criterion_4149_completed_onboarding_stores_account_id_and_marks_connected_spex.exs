defmodule MetricFlowSpex.CompletedOnboardingStoresAccountIdSpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Completed onboarding stores account id and marks connected" do
    scenario "agency with a completed Stripe account is shown as connected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_stripe_connect

      when_ "the admin views the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the connected status and the stored account id", context do
        html = render(context.view)
        assert html =~ "Connected"
        assert html =~ "acct_test_"
        {:ok, context}
      end
    end
  end
end
