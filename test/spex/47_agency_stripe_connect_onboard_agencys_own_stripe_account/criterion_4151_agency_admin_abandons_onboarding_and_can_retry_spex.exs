defmodule MetricFlowSpex.AbandonedOnboardingOffersRetrySpex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Agency admin abandons onboarding and can retry" do
    scenario "admin who left onboarding incomplete sees an option to resume" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_incomplete_stripe_connect

      when_ "the admin returns to the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the admin can resume onboarding", context do
        assert has_element?(context.view, "[data-role=connect-stripe]")
        html = render(context.view)
        assert html =~ "Resume Onboarding"
        {:ok, context}
      end
    end
  end
end
