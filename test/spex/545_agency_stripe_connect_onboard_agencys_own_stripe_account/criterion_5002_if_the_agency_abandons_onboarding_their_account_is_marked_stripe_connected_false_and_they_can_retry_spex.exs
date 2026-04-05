defmodule MetricFlowSpex.AbandonedOnboardingCanRetrySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Abandoned onboarding allows retry" do
    scenario "agency that abandoned onboarding sees retry option" do
      given_ :user_logged_in_as_owner

      given_ "the admin visits the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an option to connect Stripe", context do
        html = render(context.view)
        assert html =~ "Connect"
        :ok
      end
    end
  end
end
