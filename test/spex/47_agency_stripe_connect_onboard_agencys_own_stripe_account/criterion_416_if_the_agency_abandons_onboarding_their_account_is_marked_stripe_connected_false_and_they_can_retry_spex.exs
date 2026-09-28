defmodule MetricFlowSpex.AbandonedOnboardingCanRetrySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Abandoned onboarding allows retry", criterion: 416 do
    scenario "agency that abandoned onboarding sees retry option" do
      given_ :user_logged_in_as_owner

      given_ "the admin visits the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an option to connect Stripe", context do
        html = render(context.view)
        assert html =~ "Connect"
        {:ok, context}
      end
    end
  end
end
