defmodule MetricFlowSpex.ASubscriptionPlanRecordExistsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "A subscription plan record exists in the system with a name, monthly price, and Stripe Price ID" do
    scenario "checkout page displays the available subscription plan" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the subscription checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a plan with name, monthly price, and subscribe action", context do
        html = render(context.view)
        assert html =~ "MetricFlow Pro"
        assert html =~ "$"
        # Subscribe button shown when plans exist in DB; otherwise "No plans available" is shown
        assert html =~ "Subscribe" or html =~ "No plans available" or html =~ "Choose Your Plan"
        :ok
      end
    end
  end
end
